module Api
  module V1
    class StatusSerializer
      # @param status [Status]
      # @return [Hash]
      def self.render(status)
        {
          id: status.id,
          name: status.name,
          category: status.category,
          position: status.position
        }
      end
    end
  end
end
