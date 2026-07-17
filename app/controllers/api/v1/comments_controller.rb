module Api
  module V1
    class CommentsController < BaseController
      before_action :set_item

      def index
        comments = @item.comments.includes(:user).order(:created_at)
        render json: { comments: comments.map { |comment| CommentSerializer.render(comment) } }
      end

      def create
        comment = @item.comments.new(comment_params.merge(user: current_user))
        comment.save!
        render json: CommentSerializer.render(comment), status: :created
      end

      private

      def set_item
        @item = Item.joins(:project)
                    .where(projects: { organization_id: current_organization.id })
                    .find(params[:item_id])
      end

      def comment_params
        params.require(:comment).permit(:body)
      end
    end
  end
end
