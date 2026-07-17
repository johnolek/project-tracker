class Comparison < ApplicationRecord
  OUTCOMES = %w[a_wins b_wins draw].freeze

  belongs_to :item_a, class_name: "Item"
  belongs_to :item_b, class_name: "Item"
  belongs_to :user

  validates :outcome, inclusion: { in: OUTCOMES }
  validate :items_differ
  validate :items_in_same_organization

  after_create :recompute_strengths
  after_destroy :recompute_strengths

  # All comparisons whose items belong to the given organization. Filtering on
  # item_a alone is sufficient: the same-organization validation guarantees both
  # items share an organization.
  #
  # @param organization [Organization]
  scope :for_organization, ->(organization) {
    where(item_a_id: Item.joins(:project).where(projects: { organization_id: organization.id }).select(:id))
  }

  # @param organization [Organization]
  # @return [Hash{Integer => Integer}] item_id => number of comparisons it appears in
  def self.counts_by_item(organization:)
    counts = Hash.new(0)
    for_organization(organization).pluck(:item_a_id, :item_b_id).each do |item_a_id, item_b_id|
      counts[item_a_id] += 1
      counts[item_b_id] += 1
    end
    counts
  end

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

  def recompute_strengths
    organization = item_a&.project&.organization
    Item.recompute_strengths(organization: organization) if organization
  end

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
