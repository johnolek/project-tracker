class Comment < ApplicationRecord
  # A comment either originates from a signed-in web session ("web") or from a
  # bearer-token API call ("api", i.e. Claude/an LLM driving the tracker).
  SOURCES = %w[web api].freeze

  has_rich_text :body

  belongs_to :item
  belongs_to :user

  validates :body, presence: true
  validates :source, inclusion: { in: SOURCES }

  # @return [Boolean] true when the comment was posted through the JSON API
  #   (a machine-posted comment) rather than the web UI
  def from_api?
    source == "api"
  end

  # JSON shape the CommentEditor island renders and receives back after every
  # inline save. body_html is the rendered rich text for display; body_trix
  # seeds the rhino editor when editing begins.
  #
  # @return [Hash]
  def edit_payload
    {
      id: id,
      body_html: body.to_s,
      body_trix: body.body&.to_trix_html.to_s,
      updated_at: updated_at.to_i
    }
  end
end
