module Api
  module V1
    class ItemSerializer
      # @param item [Item]
      # @return [Hash] key is the human reference ("PROJ-12"), number its
      #   project-scoped sequence; notes_html is the rendered rich-text HTML
      #   ("" when blank), notes_text its plain-text form; tags are names
      #   sorted alphabetically; provenance derives from source +
      #   ai_reviewed_at (user_created / ai_created / ai_reviewed); parent is
      #   nil for root items; children are direct sub-items by ascending number;
      #   links buckets typed relationships (blocks / blocked_by / relates_to)
      #   as references carrying the link_id used to DELETE the link
      def self.render(item)
        {
          id: item.id,
          key: item.key,
          number: item.number,
          title: item.title,
          item_type: item.item_type,
          points: item.points,
          strength: item.strength,
          source: item.source,
          ai_reviewed_at: item.ai_reviewed_at,
          provenance: item.provenance,
          needs_review: item.needs_review?,
          review_requested_at: item.review_requested_at,
          review_note: item.review_note,
          status: StatusSerializer.render(item.status),
          project: {
            id: item.project.id,
            name: item.project.name,
            slug: item.project.slug
          },
          parent: item.parent && reference(item.parent),
          children: item.children.map { |child| reference(child) },
          links: item.grouped_links.transform_values do |pairs|
            pairs.map { |link, other| reference(other).merge(link_id: link.id) }
          end,
          tags: item.tags.map(&:name).sort,
          notes_html: item.notes.to_s,
          notes_text: item.notes.to_plain_text,
          created_at: item.created_at,
          updated_at: item.updated_at
        }
      end

      # Compact form for tree neighbors (parent/children) — enough to follow
      # up with a show call without embedding whole items recursively.
      #
      # @param item [Item]
      # @return [Hash]
      def self.reference(item)
        { id: item.id, key: item.key, title: item.title }
      end
    end
  end
end
