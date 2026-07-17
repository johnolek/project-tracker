module Api
  module V1
    class TagsController < BaseController
      def index
        tags = current_organization.tags.order(:name)
        render json: { tags: tags.map { |tag| TagSerializer.render(tag) } }
      end
    end
  end
end
