module Api
  module V1
    class CommentSerializer
      # @param comment [Comment]
      # @return [Hash] body_html is the rendered rich-text HTML (wrapped in a
      #   trix-content div), body_text its plain-text form; body aliases
      #   body_text for backward compatibility with existing consumers.
      #   source is "web" or "api".
      def self.render(comment)
        {
          id: comment.id,
          body: comment.body.to_plain_text,
          body_html: comment.body.to_s,
          body_text: comment.body.to_plain_text,
          source: comment.source,
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
