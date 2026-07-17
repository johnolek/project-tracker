module Api
  module V1
    class StatusesController < BaseController
      def index
        statuses = current_organization.statuses.ordered
        render json: { statuses: statuses.map { |status| StatusSerializer.render(status) } }
      end
    end
  end
end
