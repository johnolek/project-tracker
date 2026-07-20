module Api
  module V1
    class CommentsController < BaseController
      before_action :set_item

      def index
        comments = @item.comments.includes(:user).order(:created_at)
        render json: { comments: comments.map { |comment| CommentSerializer.render(comment) } }
      end

      # A bearer-token comment is by definition machine-posted, so every comment
      # created here is stamped source: "api". The body is HTML, sanitized on
      # write to the tags the rhino editor round-trips (PROJ-72).
      def create
        comment = @item.comments.new(comment_params.merge(user: current_user, source: "api"))
        comment.save!
        render json: CommentSerializer.render(comment), status: :created
      end

      private

      def set_item
        @item = find_organization_item(params[:item_id])
      end

      def comment_params
        attributes = params.require(:comment).permit(:body)
        attributes[:body] = RhinoHtml.sanitize(attributes[:body]) if attributes.key?(:body)
        attributes
      end
    end
  end
end
