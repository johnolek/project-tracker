class LinksController < ApplicationController
  before_action :require_login
  before_action :set_project_and_item

  # The add-relationship form on the item page. kind mirrors the API's accepted
  # names: blocks, blocked_by (stored as the reversed blocks edge), relates_to.
  def create
    target = organization_items.find(link_params[:target_id])
    link =
      case link_params[:kind]
      when "blocked_by" then ItemLink.new(source: target, target: @item, kind: "blocks")
      when "blocks", "relates_to" then ItemLink.new(source: @item, target: target, kind: link_params[:kind])
      else return redirect_to item_page, alert: "Unknown relationship kind."
      end

    if link.save
      redirect_to item_page, notice: "Link added."
    else
      redirect_to item_page, alert: link.errors.full_messages.to_sentence
    end
  end

  def destroy
    link = ItemLink.where(source_id: @item.id).or(ItemLink.where(target_id: @item.id)).find(params[:id])
    link.destroy
    redirect_to item_page, notice: "Link removed."
  end

  private

  def set_project_and_item
    @project = current_organization.projects.find(params[:project_id])
    @item = @project.items.find(params[:item_id])
  end

  def organization_items
    Item.joins(:project).where(projects: { organization_id: current_organization.id })
  end

  def item_page
    project_item_path(@project, @item)
  end

  def link_params
    params.require(:link).permit(:kind, :target_id)
  end
end
