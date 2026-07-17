class ItemsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :set_item, only: %i[show edit update destroy move]

  def show
  end

  def new
    @item = @project.items.new
  end

  def edit
  end

  def create
    @item = @project.items.new(item_params)

    if @item.save
      redirect_to project_item_path(@project, @item), notice: "Item created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @item.update(item_params)
      redirect_to project_item_path(@project, @item), notice: "Item updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @item.destroy
    redirect_to project_path(@project), notice: "Item deleted."
  end

  # Drag-and-drop status change from the board. Scopes the target status to the
  # project's organization so a foreign status_id 404s rather than leaking across
  # tenants; the Item#broadcast_board echo reconciles every subscribed board.
  def move
    status = @project.organization.statuses.find(params.require(:status_id))
    @item.update!(status: status)
    head :no_content
  end

  private

  def set_project
    @project = current_organization.projects.find(params[:project_id])
  end

  def set_item
    @item = @project.items.find(params[:id])
  end

  def item_params
    params.require(:item).permit(:title, :notes, :points, :item_type, :status_id, :tag_names)
  end
end
