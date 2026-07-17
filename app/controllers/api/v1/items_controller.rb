module Api
  module V1
    class ItemsController < BaseController
      SORT_COLUMNS = %w[created_at points strength title].freeze
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      before_action :set_item, only: %i[show update destroy advance]

      def index
        items = filtered_items
        total = items.count(:id)
        items = items.order(sort_order)
                     .offset((page - 1) * per_page)
                     .limit(per_page)
                     .includes(:status, :project, :tags, rich_text_notes: { embeds_attachments: :blob })

        render json: {
          items: items.map { |item| ItemSerializer.render(item) },
          page: page,
          per_page: per_page,
          total: total
        }
      end

      def show
        render json: ItemSerializer.render(@item)
      end

      def create
        project = current_organization.projects.find(params[:project_id])
        item = project.items.new(item_attributes)
        return unless assign_status(item: item)

        item.save!
        render json: ItemSerializer.render(item), status: :created
      end

      def update
        @item.assign_attributes(item_attributes)
        return unless assign_status(item: @item)

        @item.save!
        render json: ItemSerializer.render(@item)
      end

      def destroy
        @item.destroy!
        head :no_content
      end

      def advance
        statuses = current_organization.statuses.ordered.to_a
        current_index = statuses.index { |status| status.id == @item.status_id }
        next_status = current_index && statuses[current_index + 1]

        if next_status
          @item.update!(status: next_status)
          render json: ItemSerializer.render(@item)
        else
          render json: { error: "Item is already in the final status" }, status: :unprocessable_entity
        end
      end

      private

      def set_item
        @item = organization_items.find(params[:id])
      end

      def organization_items
        Item.joins(:project).where(projects: { organization_id: current_organization.id })
      end

      def item_params
        params.require(:item).permit(:title, :notes, :item_type, :points, :status, :tags, tags: [])
      end

      def item_attributes
        attributes = item_params.slice(:title, :notes, :item_type, :points).to_h
        attributes[:tag_names] = item_params[:tags] if item_params.key?(:tags)
        attributes
      end

      # Resolves the optional status-by-name param, case-insensitively, within
      # the key's organization. Renders a 422 and returns false on unknown names.
      #
      # @param item [Item]
      # @return [Boolean] whether the request should proceed
      def assign_status(item:)
        name = item_params[:status]
        return true if name.blank?

        status = current_organization.statuses.where("LOWER(name) = ?", name.downcase).first
        if status.nil?
          render json: { error: "Unknown status: #{name}" }, status: :unprocessable_entity
          return false
        end

        item.status = status
        true
      end

      def filtered_items
        items = base_scope
        items = filter_status(items)
        items = filter_item_type(items)
        items = filter_tags(items)
        items = filter_points(items)
        filter_title(items)
      end

      # Path project_id (nested index) and query project_id (org-wide filter)
      # behave identically: both 404 when the project isn't in the organization.
      def base_scope
        if params[:project_id].present?
          current_organization.projects.find(params[:project_id]).items
        else
          organization_items
        end
      end

      def filter_status(items)
        return items if params[:status].blank?

        items.joins(:status).where("LOWER(statuses.name) = ?", params[:status].downcase)
      end

      def filter_item_type(items)
        return items if params[:item_type].blank?

        items.where(item_type: params[:item_type])
      end

      def filter_tags(items)
        names = params[:tags].to_s.split(",").map { |name| name.strip.downcase }.reject(&:blank?).uniq
        return items if names.empty?

        if params[:tags_match] == "all"
          matching = Item.joins(:tags)
                         .where("LOWER(tags.name) IN (?)", names)
                         .group(:id)
                         .having("COUNT(DISTINCT LOWER(tags.name)) = ?", names.size)
                         .select(:id)
          items.where(id: matching)
        else
          items.joins(:tags).where("LOWER(tags.name) IN (?)", names).distinct
        end
      end

      def filter_points(items)
        items = items.where(points: params[:points]) if params[:points].present?
        items = items.where("items.points < ?", params[:points_lt]) if params[:points_lt].present?
        items = items.where("items.points <= ?", params[:points_lte]) if params[:points_lte].present?
        items = items.where("items.points > ?", params[:points_gt]) if params[:points_gt].present?
        items = items.where("items.points >= ?", params[:points_gte]) if params[:points_gte].present?
        items
      end

      def filter_title(items)
        return items if params[:q].blank?

        items.where("items.title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%")
      end

      def sort_order
        column = SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : "created_at"
        direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : default_direction(column)
        { column => direction, "id" => direction }
      end

      def default_direction(column)
        column == "created_at" ? "desc" : "asc"
      end

      def page
        @page ||= [ params[:page].to_i, 1 ].max
      end

      def per_page
        @per_page ||= (params[:per_page].present? ? params[:per_page].to_i : DEFAULT_PER_PAGE).clamp(1, MAX_PER_PAGE)
      end
    end
  end
end
