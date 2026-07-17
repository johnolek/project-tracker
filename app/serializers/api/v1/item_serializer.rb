module Api
  module V1
    class ItemSerializer
      # @param item [Item]
      # @return [Hash] notes_html is the rendered rich-text HTML ("" when blank),
      #   notes_text its plain-text form; tags are names sorted alphabetically
      def self.render(item)
        {
          id: item.id,
          title: item.title,
          item_type: item.item_type,
          points: item.points,
          rating: item.rating,
          status: StatusSerializer.render(item.status),
          project: {
            id: item.project.id,
            name: item.project.name
          },
          tags: item.tags.map(&:name).sort,
          notes_html: item.notes.to_s,
          notes_text: item.notes.to_plain_text,
          created_at: item.created_at,
          updated_at: item.updated_at
        }
      end
    end
  end
end
