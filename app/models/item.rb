class Item < ApplicationRecord
  ITEM_TYPES = %w[bug task enhancement idea].freeze

  has_rich_text :notes

  belongs_to :project
  belongs_to :status
  has_many :comments, dependent: :destroy
  has_many :comparisons_as_item_a, class_name: "Comparison", foreign_key: :item_a_id, dependent: :destroy, inverse_of: :item_a
  has_many :comparisons_as_item_b, class_name: "Comparison", foreign_key: :item_b_id, dependent: :destroy, inverse_of: :item_b

  validates :title, presence: true
  validates :rating, :rating_deviation, :volatility, presence: true, numericality: true
  validates :item_type, inclusion: { in: ITEM_TYPES }
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
  # groups, and disappear live on every subscribed view.
  def broadcast_board
    broadcast_replace_to(
      [ project, "items" ],
      target: ActionView::RecordIdentifier.dom_id(project, :board),
      partial: "items/board",
      locals: { project: project }
    )
  end
end
