module Api
  module V1
    class CommentsController < BaseController
      before_action :set_item, only: %i[index create]

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

      # Flat-path update (PATCH /comments/:id) so a comment is addressable by
      # its id alone; the body is sanitized like create's. Any comment on an
      # organization item is editable, regardless of author — this is how old
      # unreadable machine comments get cleaned up.
      def update
        comment = organization_comment(params[:id])
        comment.update!(comment_params)
        render json: CommentSerializer.render(comment)
      end

      private

      # @param id [String, Integer]
      # @return [Comment]
      def organization_comment(id)
        Comment.joins(item: :project)
               .where(projects: { organization_id: current_organization.id })
               .find(id)
      end

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
