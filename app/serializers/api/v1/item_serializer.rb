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
      #   as references carrying the link_id used to DELETE the link;
      #   attachments are the images/files embedded in the notes, each with a
      #   directly fetchable url (absolute when the request host is known)
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
          metadata: item.metadata,
          notes_html: item.notes.to_s,
          notes_text: item.notes.to_plain_text,
          attachments: attachments(item),
          created_at: item.created_at,
          updated_at: item.updated_at
        }
      end

      # Files embedded in the item's rich-text notes (Trix uploads), in
      # document order. width/height come from image analysis and are nil for
      # non-images or not-yet-analyzed blobs.
      #
      # @param item [Item]
      # @return [Array<Hash>]
      def self.attachments(item)
        item.notes.embeds.map do |embed|
          blob = embed.blob
          {
            filename: blob.filename.to_s,
            content_type: blob.content_type,
            byte_size: blob.byte_size,
            width: blob.metadata["width"],
            height: blob.metadata["height"],
            url: blob_url(blob)
          }
        end
      end

      # Redirect URL for a blob — absolute when the request host has been set on
      # ActiveStorage::Current (the normal API path), falling back to a relative
      # path in contexts without a request (console, some tests). The signed
      # blob id in the URL is the capability; no bearer token is needed to fetch.
      #
      # @param blob [ActiveStorage::Blob]
      # @return [String]
      def self.blob_url(blob)
        helpers = Rails.application.routes.url_helpers
        options = ActiveStorage::Current.url_options
        if options && options[:host].present?
          helpers.rails_blob_url(blob, **options)
        else
          helpers.rails_blob_path(blob)
        end
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
