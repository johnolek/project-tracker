class CommentsController < ApplicationController
  before_action :require_login
  before_action :set_project
  before_action :set_item

  def create
    comment = @item.comments.new(comment_params.merge(user: current_user))

    if comment.save
      redirect_to project_item_path(@project, @item), notice: "Comment added."
    else
      redirect_to project_item_path(@project, @item), alert: comment.errors.full_messages.to_sentence
    end
  end

  private

  def set_project
    @project = current_organization.projects.find(params[:project_id])
  end

  def set_item
    @item = @project.items.find(params[:item_id])
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
