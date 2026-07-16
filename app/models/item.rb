class Item < ApplicationRecord
  ITEM_TYPES = %w[bug task enhancement idea].freeze
  SOURCES = %w[internal external].freeze

  belongs_to :project
  belongs_to :status
  has_many :comments, dependent: :destroy

  validates :title, presence: true
  validates :elo_rating, presence: true, numericality: { only_integer: true }
  validates :item_type, inclusion: { in: ITEM_TYPES }
  validates :source, inclusion: { in: SOURCES }
  validates :points, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  before_validation :assign_default_status, on: :create

  after_create :broadcast_board
  after_update :broadcast_board
  after_destroy :broadcast_board

  private

  def assign_default_status
    self.status ||= project&.organization&.default_status
  end

  # Re-renders the whole project board so items appear, move between status
  # groups, and disappear live on every subscribed view (authed and public).
  def broadcast_board
    broadcast_replace_to(
      [ project, "items" ],
      target: ActionView::RecordIdentifier.dom_id(project, :board),
      partial: "items/board",
      locals: { project: project }
    )
  end
end
