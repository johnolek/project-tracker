# A directed, typed edge between two items: the source "blocks" the target, or
# the two simply relate ("relates_to", stored one way but read symmetrically).
# Links stay within one organization; crossing projects inside it is allowed
# (a tracker item can be blocked by work in another project).
class ItemLink < ApplicationRecord
  KINDS = %w[blocks relates_to].freeze

  belongs_to :source, class_name: "Item", inverse_of: :outgoing_links
  belongs_to :target, class_name: "Item", inverse_of: :incoming_links

  validates :kind, inclusion: { in: KINDS }
  validates :target_id, uniqueness: { scope: %i[source_id kind], message: "is already linked" }
  validate :not_self_referential
  validate :within_one_organization
  validate :no_reverse_duplicate

  private

  def not_self_referential
    return unless source_id.present? && source_id == target_id

    errors.add(:target, "can't be the item itself")
  end

  def within_one_organization
    return if source.nil? || target.nil?
    return if source.project.organization_id == target.project.organization_id

    errors.add(:target, "must belong to the same organization")
  end

  # relates_to is symmetric, so A→B and B→A would be the same statement twice;
  # a mutual "blocks" pair is a real (deadlocked) state and stays expressible.
  def no_reverse_duplicate
    return unless kind == "relates_to"
    return unless ItemLink.exists?(source_id: target_id, target_id: source_id, kind: kind)

    errors.add(:target, "is already linked")
  end
end
