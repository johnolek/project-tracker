module Settings
  class ItemTypesController < ApplicationController
    before_action :require_login
    before_action :set_item_type, only: %i[update destroy move]

    def index
      @item_types = item_types_scope
      @item_type = current_organization.item_types.new
    end

    def create
      @item_type = current_organization.item_types.new(item_type_params.merge(position: next_position))

      if @item_type.save
        redirect_to settings_item_types_path, notice: "Item type created."
      else
        @item_types = item_types_scope
        render :index, status: :unprocessable_entity
      end
    end

    def update
      if @item_type.update(item_type_params)
        redirect_to settings_item_types_path, notice: "Item type updated."
      else
        redirect_to settings_item_types_path, alert: @item_type.errors.full_messages.to_sentence
      end
    end

    def destroy
      if @item_type.destroy
        redirect_to settings_item_types_path, notice: "Item type deleted."
      else
        redirect_to settings_item_types_path, alert: @item_type.errors.full_messages.to_sentence
      end
    end

    # Swaps position with the adjacent type in the requested direction so the
    # up/down arrows reorder the type list one step at a time.
    def move
      neighbor = adjacent_item_type(direction: params[:direction])

      if neighbor
        ItemType.transaction do
          moved_from = @item_type.position
          @item_type.update_column(:position, neighbor.position)
          neighbor.update_column(:position, moved_from)
        end
      end

      redirect_to settings_item_types_path
    end

    private

    def set_item_type
      @item_type = current_organization.item_types.find(params[:id])
    end

    def item_types_scope
      current_organization.item_types.ordered
    end

    # @return [Integer] the position after the last type, so a new type appends
    def next_position
      (current_organization.item_types.maximum(:position) || 0) + 1
    end

    # @param direction [String] "up" (toward the front) or "down" (toward the back)
    # @return [ItemType, nil] the neighbouring type to swap with, if any
    def adjacent_item_type(direction:)
      case direction
      when "up"
        current_organization.item_types.where("position < ?", @item_type.position).order(position: :desc).first
      when "down"
        current_organization.item_types.where("position > ?", @item_type.position).order(:position).first
      end
    end

    # Color is optional on create: a blank value lets the model auto-assign an
    # unused palette color, which the inline color picker can then override.
    def item_type_params
      params.require(:item_type).permit(:name, :color)
    end
  end
end
