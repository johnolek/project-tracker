module Api
  module V1
    class CommentSerializer
      # @param comment [Comment]
      # @return [Hash]
      def self.render(comment)
        {
          id: comment.id,
          body: comment.body,
          user: {
            id: comment.user.id,
            username: comment.user.username
          },
          created_at: comment.created_at
        }
      end
    end
  end
end
