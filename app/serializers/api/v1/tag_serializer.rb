module Api
  module V1
    class TagSerializer
      # @param tag [Tag]
      # @return [Hash]
      def self.render(tag)
        {
          id: tag.id,
          name: tag.name
        }
      end
    end
  end
end
