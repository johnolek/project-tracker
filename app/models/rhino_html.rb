# Sanitizes API-submitted rich text (comment bodies, item notes — PROJ-72)
# down to the tags the rhino editor produces, so everything stored via the API
# can be re-edited in the web UI without the editor dropping content. Applied
# on write; ActionText's own render-time sanitization is unchanged.
#
# Disallowed tags are stripped but their text is kept (script/style contents
# are removed entirely). Plain text passes through untouched, so callers that
# want line breaks must send <br> or block tags.
module RhinoHtml
  # Rhino's default Trix-parity set: bold, italic, strikethrough, inline code,
  # links, heading, quote, code block, lists, plus the block/break containers
  # trix and tiptap emit. b/i/s are included because the editor parses them
  # into strong/em/del on edit.
  ALLOWED_TAGS = %w[p div br h1 blockquote pre code strong em b i del s strike a ul ol li].freeze
  ALLOWED_ATTRIBUTES = %w[href].freeze

  # @param html [String, nil]
  # @return [String] the sanitized HTML, or "" for blank input
  def self.sanitize(html)
    return "" if html.blank?

    fragment = Loofah.html5_fragment(html)
    fragment.css("script, style").each(&:remove)
    Rails::HTML5::SafeListSanitizer.new.sanitize(fragment.to_html, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end
end
