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

  # JSON-only inline edit from the CommentEditor island (PROJ-75). Any member
  # of the organization can edit any comment, matching item notes.
  def update
    comment = @item.comments.find(params[:id])

    if comment.update(comment_params)
      render json: comment.edit_payload
    else
      render json: { errors: comment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = find_project!(params[:project_id])
  end

  def set_item
    @item = find_item!(params[:item_id], scope: @project.items)
  end

  def comment_params
    params.require(:comment).permit(:body)
  end
end
