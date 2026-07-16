class Comparison < ApplicationRecord
  OUTCOMES = %w[a_wins b_wins draw].freeze

  belongs_to :item_a, class_name: "Item"
  belongs_to :item_b, class_name: "Item"
  belongs_to :user

  validates :outcome, inclusion: { in: OUTCOMES }
  validate :items_differ
  validate :items_in_same_organization

  # @return [Item, nil] the winning item, or nil for a draw
  def winner
    case outcome
    when "a_wins" then item_a
    when "b_wins" then item_b
    end
  end

  # @return [Item, nil] the losing item, or nil for a draw
  def loser
    case outcome
    when "a_wins" then item_b
    when "b_wins" then item_a
    end
  end

  # @return [Boolean]
  def draw?
    outcome == "draw"
  end

  private

  def items_differ
    return if item_a_id.nil? || item_b_id.nil?

    errors.add(:item_b, "must be different from item A") if item_a_id == item_b_id
  end

  # Same-organization (rather than same-project) is enforced: priority ranking
  # spans a whole organization's backlog, which may cross projects.
  def items_in_same_organization
    return if item_a.nil? || item_b.nil?

    if item_a.project.organization_id != item_b.project.organization_id
      errors.add(:item_b, "must belong to the same organization as item A")
    end
  end
end
