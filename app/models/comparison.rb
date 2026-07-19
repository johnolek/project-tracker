class Comparison < ApplicationRecord
  OUTCOMES = %w[a_wins b_wins draw].freeze

  belongs_to :item_a, class_name: "Item"
  belongs_to :item_b, class_name: "Item"
  belongs_to :user

  validates :outcome, inclusion: { in: OUTCOMES }
  validate :items_differ
  validate :items_in_same_project
  validate :pair_not_already_compared

  after_create :recompute_strengths
  after_destroy :recompute_strengths

  # All comparisons whose items belong to the given organization. Filtering on
  # item_a alone is sufficient: the same-project validation guarantees both
  # items share a project (and therefore an organization).
  #
  # @param organization [Organization]
  scope :for_organization, ->(organization) {
    where(item_a_id: Item.joins(:project).where(projects: { organization_id: organization.id }).select(:id))
  }

  # @param project [Project]
  scope :for_project, ->(project) { where(item_a_id: project.items.select(:id)) }

  # The unordered pairs already compared in the project, each as a sorted
  # [lower_id, higher_id] tuple, for cheap membership tests during pairing.
  #
  # @param project [Project]
  # @return [Set<Array(Integer, Integer)>]
  def self.compared_pairs(project:)
    for_project(project).pluck(:item_a_id, :item_b_id).map { |a, b| a < b ? [ a, b ] : [ b, a ] }.to_set
  end

  # @param project [Project]
  # @return [Hash{Integer => Integer}] item_id => number of comparisons it appears in
  def self.counts_by_item(project:)
    counts = Hash.new(0)
    for_project(project).pluck(:item_a_id, :item_b_id).each do |item_a_id, item_b_id|
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

  # A pair only needs comparing once, in either direction — Bradley-Terry gains
  # nothing from a repeat. Matched on the unordered pair so A-vs-B and B-vs-A
  # count as the same. A DB-level unique index on LEAST/GREATEST is the real
  # guard; this validation just turns the race into a friendly error.
  def pair_not_already_compared
    return if item_a_id.nil? || item_b_id.nil? || item_a_id == item_b_id

    lo, hi = [ item_a_id, item_b_id ].minmax
    scope = Comparison.where(
      "LEAST(item_a_id, item_b_id) = ? AND GREATEST(item_a_id, item_b_id) = ?", lo, hi
    )
    scope = scope.where.not(id: id) if persisted?

    errors.add(:base, "These two items have already been compared.") if scope.exists?
  end

  # Prioritization is per-project: pairs are only meaningful inside one
  # project's backlog, and keeping the comparison graph within a project keeps
  # the fitted strengths honestly comparable.
  def items_in_same_project
    return if item_a.nil? || item_b.nil?

    if item_a.project_id != item_b.project_id
      errors.add(:item_b, "must belong to the same project as item A")
    end
  end
end
