class ItemType < ApplicationRecord
  # Warm Southwest-leaning hues used when a type is created without an explicit
  # color. The first three are the danger/success/warning values the theme
  # resolves for the seeded bug/feature/idea types; the rest widen the range so
  # a handful of custom types each land on a distinct color.
  PALETTE = %w[
    #9D2925
    #4C633B
    #F5AE0A
    #B5651D
    #2E6E6A
    #8C4B7F
    #5A6C8C
    #A03E52
    #7A5230
    #C77D3C
  ].freeze

  belongs_to :organization

  validates :name, presence: true, uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :color, presence: true, format: { with: /\A#(?:\h{3}|\h{6})\z/, message: "must be a hex color like #3273dc" }
  validates :position, presence: true, numericality: { only_integer: true }

  before_validation :assign_default_color, on: :create

  after_update :cascade_rename_to_items
  before_destroy :ensure_no_items_using

  scope :ordered, -> { order(:position) }

  # @param organization [Organization]
  # @return [Hash{String => String}] each type name mapped to its hex color
  def self.color_map_for(organization)
    ordered.where(organization_id: organization.id).pluck(:name, :color).to_h
  end

  # Near-black or white foreground for a hex background, chosen by perceived
  # (Rec. 601) luminance so a type chip's label stays readable on any color.
  #
  # @param hex [String, nil] a "#rgb" or "#rrggbb" color
  # @return [String, nil] "#1a1a1a" on light backgrounds, "#ffffff" on dark ones
  def self.readable_text_color(hex)
    return nil if hex.blank?

    digits = hex.delete("#")
    digits = digits.chars.map { |char| char * 2 }.join if digits.length == 3
    r, g, b = digits.scan(/../).map { |pair| pair.to_i(16) }
    luminance = (0.299 * r) + (0.587 * g) + (0.114 * b)
    luminance > 150 ? "#1a1a1a" : "#ffffff"
  end

  # @return [String] the readable foreground for this type's color
  def text_color
    self.class.readable_text_color(color)
  end

  # Items in this type's organization whose denormalized item_type name still
  # matches — the surface that blocks a delete and gets renamed on a rename.
  #
  # @return [ActiveRecord::Relation<Item>]
  def items_using
    Item.joins(:project)
        .where(projects: { organization_id: organization_id })
        .where("LOWER(items.item_type) = ?", name.downcase)
  end

  private

  # Picks an unused palette color on create, falling back to any palette color
  # once every hue is taken. Runs in normal Rails runtime, so sampling is fine.
  def assign_default_color
    return if color.present?

    used = organization ? organization.item_types.pluck(:color) : []
    available = PALETTE - used
    self.color = (available.presence || PALETTE).sample
  end

  # Keeps the denormalized items.item_type strings in step with a rename. Runs
  # inside the save transaction so the rename and the item updates commit together.
  def cascade_rename_to_items
    return unless saved_change_to_name?

    old_name, new_name = saved_change_to_name
    Item.joins(:project)
        .where(projects: { organization_id: organization_id })
        .where("LOWER(items.item_type) = ?", old_name.downcase)
        .update_all(item_type: new_name)
  end

  def ensure_no_items_using
    return unless items_using.exists?

    errors.add(:base, "Cannot delete record because dependent items exist")
    throw :abort
  end
end
