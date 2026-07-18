module Api
  module V1
    class LinksController < BaseController
      # Kind names accepted on create. blocked_by is directional sugar: it
      # stores the reversed "blocks" edge so both ends of a blocking pair can
      # be declared from whichever item is at hand.
      ACCEPTED_KINDS = %w[blocks blocked_by relates_to].freeze

      # POST /api/v1/items/:item_id/links with { link: { kind:, target: } };
      # target is an item id or human key. Responds with the full source item
      # so the caller sees the updated links buckets.
      def create
        item = find_organization_item(params[:item_id])
        return unless (kind = accepted_kind)
        return unless (target = resolve_target)

        link =
          case kind
          when "blocked_by" then ItemLink.new(source: target, target: item, kind: "blocks")
          else ItemLink.new(source: item, target: target, kind: kind)
          end
        link.save!
        render json: ItemSerializer.render(item.reload), status: :created
      end

      # DELETE /api/v1/links/:id — the link id is included with every linked
      # reference in the item JSON.
      def destroy
        link = ItemLink.joins(source: :project)
                       .where(projects: { organization_id: current_organization.id })
                       .find(params[:id])
        link.destroy!
        head :no_content
      end

      private

      def link_params
        params.require(:link).permit(:kind, :target)
      end

      # @return [String, nil] the validated kind, or nil after rendering a 422
      def accepted_kind
        kind = link_params[:kind].to_s
        return kind if ACCEPTED_KINDS.include?(kind)

        render json: { error: "Unknown kind: #{kind} (use #{ACCEPTED_KINDS.join(', ')})" },
               status: :unprocessable_entity
        nil
      end

      # @return [Item, nil] the resolved target, or nil after rendering a 422
      def resolve_target
        find_organization_item(link_params[:target].to_s)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "Unknown target: #{link_params[:target]}" }, status: :unprocessable_entity
        nil
      end
    end
  end
end
