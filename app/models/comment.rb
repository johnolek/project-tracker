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
end
