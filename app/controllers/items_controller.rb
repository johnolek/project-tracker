class ItemsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :set_item, only: %i[show edit update destroy move]

  def show
    @comments = @item.comments.includes(:user).with_rich_text_body.order(:created_at)
    @new_comment = @item.comments.new
  end

  def new
    @item = @project.items.new(status: preselected_status)
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
      respond_to do |format|
        format.html { redirect_to project_item_path(@project, @item), notice: "Item updated." }
        format.json { render json: @item.detail_payload }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @item.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @item.destroy
    redirect_to project_path(@project), notice: "Item deleted."
  end

  # Drag-and-drop status change from the board. Scopes the target status to the
  # project's organization so a foreign status_id 404s rather than leaking across
  # tenants; the BoardChannel upsert echo reconciles every subscribed board.
  def move
    status = @project.organization.statuses.find(params.require(:status_id))
    @item.update!(status: status)
    head :no_content
  end

  private

  def set_project
    @project = current_organization.projects.find(params[:project_id])
  end

  # Status shown selected on the new-item form. The board's add-card button
  # passes params[:status_id]; it is honored only when it belongs to the org
  # (a foreign or unknown id is ignored) and otherwise falls back to the org's
  # default so the form mirrors the status create would assign.
  #
  # @return [Status, nil]
  def preselected_status
    requested = current_organization.statuses.find_by(id: params[:status_id]) if params[:status_id].present?
    requested || current_organization.default_status
  end

  def set_item
    @item = @project.items.find(params[:id])
  end

  # tag_names is permitted in both shapes: the classic form posts one
  # comma-separated string, the inline sidebar PATCHes a JSON array.
  def item_params
    params.require(:item).permit(:title, :notes, :points, :item_type, :status_id, :tag_names, tag_names: [])
  end
end
