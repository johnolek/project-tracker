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
                     .includes(:status, :project, :tags, :children, { parent: :project },
                               { outgoing_links: { target: :project }, incoming_links: { source: :project } },
                               rich_text_notes: { embeds_attachments: :blob })

        render json: {
          items: items.map { |item| ItemSerializer.render(item) },
          page: page,
          per_page: per_page,
          total: total
        }
      end

      def show
        return redirect_to api_v1_item_path(@item), status: :moved_permanently if stale_item_key?(params[:id], @item)

        render json: ItemSerializer.render(@item)
      end

      # Items created here are stamped source: "api" — the provenance that
      # renders as "AI created" (Claude drives the API; people use the web UI).
      def create
        project = find_organization_project(params[:project_id])
        item = project.items.new(item_attributes.merge(source: "api"))
        return unless assign_status(item: item)
        return unless assign_parent(item: item)

        item.save!
        render json: ItemSerializer.render(item), status: :created
      end

      def update
        @item.assign_attributes(item_attributes)
        apply_ai_reviewed(item: @item)
        apply_review(item: @item)
        return unless assign_status(item: @item)
        return unless assign_parent(item: @item)

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
        @item = find_organization_item(params[:id])
      end

      # Web-side drafts (PROJ-86) stay out of the API entirely.
      def organization_items
        Item.published.joins(:project).where(projects: { organization_id: current_organization.id })
      end

      def item_params
        params.require(:item).permit(:title, :notes, :item_type, :points, :status, :parent, :ai_reviewed,
                                     :review, :review_note, :tags, tags: [])
      end

      # notes arrive as HTML and are sanitized on write to the tags the rhino
      # editor round-trips (PROJ-72), like API comment bodies.
      def item_attributes
        attributes = item_params.slice(:title, :notes, :item_type, :points).to_h
        attributes[:notes] = RhinoHtml.sanitize(attributes[:notes]) if attributes.key?(:notes)
        attributes[:tag_names] = item_params[:tags] if item_params.key?(:tags)
        attributes
      end

      # Applies the optional ai_reviewed boolean: true stamps ai_reviewed_at
      # (keeping the original time on re-sends), false clears it. This is how
      # an LLM signs off after revising a person-created item (PROJ-35).
      #
      # @param item [Item]
      # @return [void]
      def apply_ai_reviewed(item:)
        return unless item_params.key?(:ai_reviewed)

        if ActiveModel::Type::Boolean.new.cast(item_params[:ai_reviewed])
          item.ai_reviewed_at ||= Time.current
        else
          item.ai_reviewed_at = nil
        end
      end

      # Applies the review flag (PROJ-65): review=true flags the item (removing
      # it from the prioritization pool), review=false clears it. review_note
      # is applied only when flagging now or already flagged (PROJ-77) — a note
      # on an unflagged item would be stored invisibly and resurrect stale on a
      # later flag.
      #
      # @param item [Item]
      # @return [void]
      def apply_review(item:)
        flagging = item_params.key?(:review) && ActiveModel::Type::Boolean.new.cast(item_params[:review])
        if item_params.key?(:review_note) && (flagging || item.review_requested_at.present?)
          item.review_note = item_params[:review_note]
        end
        return unless item_params.key?(:review)

        if ActiveModel::Type::Boolean.new.cast(item_params[:review])
          item.review_requested_at ||= Time.current
        else
          item.review_requested_at = nil
          item.review_note = nil
        end
      end

      # Resolves the optional parent param — an item id or human key, or
      # "none"/"" to clear — within the key's organization. Renders a 422 and
      # returns false when the reference doesn't resolve; same-project and
      # cycle rules are the model's validations.
      #
      # @param item [Item]
      # @return [Boolean] whether the request should proceed
      def assign_parent(item:)
        return true unless item_params.key?(:parent)

        reference = item_params[:parent].to_s.strip
        if reference.empty? || reference.casecmp("none").zero?
          item.parent = nil
        else
          item.parent = find_organization_item(reference)
        end
        true
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Unknown parent: #{reference}" }, status: :unprocessable_entity
        false
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
        items = filter_source(items)
        items = filter_ai_reviewed(items)
        items = filter_review(items)
        items = filter_parent(items)
        filter_title(items)
      end

      # Path project_id (nested index) and query project_id (org-wide filter)
      # behave identically: both 404 when the project isn't in the organization.
      def base_scope
        if params[:project_id].present?
          find_organization_project(params[:project_id]).items.published
        else
          organization_items
        end
      end

      def filter_status(items)
        return items if params[:status].blank?

        items.joins(:status).where("LOWER(statuses.name) = ?", params[:status].downcase)
      end

      # Stored types are lowercase by construction (PROJ-77); normalize the
      # query the same way so ?item_type=Bug still matches.
      def filter_item_type(items)
        return items if params[:item_type].blank?

        requested = params[:item_type].to_s.downcase
        items.where(item_type: Item::LEGACY_ITEM_TYPES.fetch(requested, requested))
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

      def filter_source(items)
        return items if params[:source].blank?

        items.where(source: params[:source])
      end

      # ai_reviewed=true keeps only signed-off items; anything else keeps the
      # unreviewed. The typical revision-workflow query is
      # source=web&ai_reviewed=false: person-created items awaiting an AI pass.
      def filter_ai_reviewed(items)
        return items if params[:ai_reviewed].blank?

        if ActiveModel::Type::Boolean.new.cast(params[:ai_reviewed])
          items.where.not(ai_reviewed_at: nil)
        else
          items.where(ai_reviewed_at: nil)
        end
      end

      # needs_review=true keeps only flagged items (the review queue);
      # needs_review=false keeps only unflagged ones.
      def filter_review(items)
        return items if params[:needs_review].blank?

        if ActiveModel::Type::Boolean.new.cast(params[:needs_review])
          items.where.not(review_requested_at: nil)
        else
          items.where(review_requested_at: nil)
        end
      end

      # parent=<id or key> keeps the direct sub-items of that item (404 when it
      # doesn't resolve, like the project_id filter); parent=none keeps roots.
      def filter_parent(items)
        return items if params[:parent].blank?
        return items.where(parent_id: nil) if params[:parent].casecmp("none").zero?

        items.where(parent_id: find_organization_item(params[:parent]).id)
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
