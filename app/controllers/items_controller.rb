class ItemsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :set_item, only: %i[show update destroy move review unreview]

  def show
    return redirect_to project_item_path(@project, @item), status: :moved_permanently if stale_project_slug?(params[:project_id])

    @children = @item.children.includes(:status, :project)
    ActiveRecord::Associations::Preloader.new(
      records: [ @item ],
      associations: { outgoing_links: { target: :project }, incoming_links: { source: :project } }
    ).call
    @links = @item.grouped_links

    # One slim scan of the project's items feeds both typeaheads (PROJ-80):
    # link targets (everything but self, newest first) and parent options
    # (minus descendants, which would cycle).
    project_items = @project.items.where.not(id: @item.id)
                            .select(:id, :number, :title, :project_id, :created_at)
                            .includes(:project).order(number: :desc).to_a
    descendant_ids = @item.descendant_ids.to_set
    @link_targets = project_items
    @parent_options = project_items.reject { |candidate| descendant_ids.include?(candidate.id) }
                                   .sort_by(&:created_at).reverse

    @comments = @item.comments.includes(:user).with_rich_text_body.order(:created_at)
    @new_comment = @item.comments.new
  end

  def new
    @item = @project.items.new(status: preselected_status, parent: preselected_parent)
  end

  # On success the notice is a sticky toast (PROJ-67): it stays up until
  # dismissed, carrying an "Add another" link back to the form with the same
  # status and parent preselected for rapid batch entry.
  def create
    @item = @project.items.new(item_params)

    if @item.save
      flash[:notice] = {
        message: "Item created.",
        sticky: true,
        action: { label: "Add another", href: new_project_item_path(@project, { status_id: @item.status_id, parent_id: @item.parent_id }.compact) }
      }
      redirect_to project_item_path(@project, @item)
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
        format.html { redirect_to project_item_path(@project, @item), alert: @item.errors.full_messages.to_sentence }
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

  # Flags the item for review (PROJ-65), removing it from the prioritization
  # pool. The optional note explains what to look at; blank is fine. Prioritizing
  # posts here and reads the item back to advance to a fresh pair.
  def review
    @item.flag_for_review!(note: params[:review_note])

    respond_to do |format|
      format.json { render json: @item.detail_payload }
      format.html { redirect_back fallback_location: project_item_path(@project, @item), notice: "Flagged for review." }
    end
  end

  # Clears the review flag, returning the item to the pool.
  def unreview
    @item.clear_review!

    respond_to do |format|
      format.json { render json: @item.detail_payload }
      format.html { redirect_back fallback_location: project_path(@project, review: 1), notice: "Review cleared." }
    end
  end

  private

  def set_project
    @project = find_project!(params[:project_id])
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

  # Parent preselected on the new-item form via params[:parent_id] (the
  # "Add sub-item" button on an item page). Ignored unless it names an item
  # in this project.
  #
  # @return [Item, nil]
  def preselected_parent
    @project.items.find_by(id: params[:parent_id]) if params[:parent_id].present?
  end

  def set_item
    @item = find_item!(params[:id], scope: @project.items)
  end

  # tag_names is permitted in both shapes: the classic form posts one
  # comma-separated string, the inline sidebar PATCHes a JSON array.
  def item_params
    params.require(:item).permit(:title, :notes, :points, :item_type, :status_id, :parent_id, :tag_names, tag_names: [])
  end
end
