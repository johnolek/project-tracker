module Settings
  class StatusesController < ApplicationController
    before_action :require_login
    before_action :set_status, only: %i[update destroy move]

    def index
      @statuses = statuses_scope
      @status = current_organization.statuses.new
    end

    def create
      @status = current_organization.statuses.new(status_params.merge(position: next_position))

      if @status.save
        redirect_to settings_statuses_path, notice: "Status created."
      else
        @statuses = statuses_scope
        render :index, status: :unprocessable_entity
      end
    end

    def update
      if @status.update(status_params)
        redirect_to settings_statuses_path, notice: "Status updated."
      else
        redirect_to settings_statuses_path, alert: @status.errors.full_messages.to_sentence
      end
    end

    def destroy
      if @status.destroy
        redirect_to settings_statuses_path, notice: "Status deleted."
      else
        redirect_to settings_statuses_path, alert: @status.errors.full_messages.to_sentence
      end
    end

    # Swaps position with the adjacent status in the requested direction so the
    # up/down arrows reorder the board columns one step at a time.
    def move
      neighbor = adjacent_status(direction: params[:direction])

      if neighbor
        Status.transaction do
          moved_from = @status.position
          @status.update_column(:position, neighbor.position)
          neighbor.update_column(:position, moved_from)
        end
      end

      redirect_to settings_statuses_path
    end

    private

    def set_status
      @status = current_organization.statuses.find(params[:id])
    end

    def statuses_scope
      current_organization.statuses.ordered
    end

    # @return [Integer] the position after the last status, so a new status appends
    def next_position
      (current_organization.statuses.maximum(:position) || 0) + 1
    end

    # @param direction [String] "up" (toward the front) or "down" (toward the back)
    # @return [Status, nil] the neighbouring status to swap with, if any
    def adjacent_status(direction:)
      case direction
      when "up"
        current_organization.statuses.where("position < ?", @status.position).order(position: :desc).first
      when "down"
        current_organization.statuses.where("position > ?", @status.position).order(:position).first
      end
    end

    def status_params
      params.require(:status).permit(:name, :category)
    end
  end
end
