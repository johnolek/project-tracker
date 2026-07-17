module Api
  module V1
    class StatusesController < BaseController
      before_action :set_status, only: %i[update destroy]

      def index
        statuses = current_organization.statuses.ordered
        render json: { statuses: statuses.map { |status| StatusSerializer.render(status) } }
      end

      def create
        status = current_organization.statuses.new(status_params)
        status.position = next_position if status.position.blank?
        status.save!
        render json: StatusSerializer.render(status), status: :created
      end

      def update
        @status.update!(status_params)
        render json: StatusSerializer.render(@status)
      end

      def destroy
        if @status.destroy
          head :no_content
        else
          render json: { error: @status.errors.full_messages.to_sentence }, status: :unprocessable_entity
        end
      end

      private

      def set_status
        @status = current_organization.statuses.find(params[:id])
      end

      # @return [Integer] the position after the last status, so a new status appends
      def next_position
        (current_organization.statuses.maximum(:position) || 0) + 1
      end

      def status_params
        params.require(:status).permit(:name, :category, :position)
      end
    end
  end
end
