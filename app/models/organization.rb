class Organization < ApplicationRecord
  DEFAULT_STATUSES = [
    { name: "New", category: "open" },
    { name: "In Progress", category: "in_progress" },
    { name: "Needs Verification", category: "in_progress" },
    { name: "Completed", category: "done" }
  ].freeze

  # Seeded for every new organization. Names match the strings the app used
  # while item types were the hardcoded Item::ITEM_TYPES; colors are the hexes
  # the Southwest theme resolves Bulma danger/success/warning to.
  DEFAULT_ITEM_TYPES = [
    { name: "bug", color: "#9D2925" },
    { name: "feature", color: "#4C633B" },
    { name: "idea", color: "#F5AE0A" }
  ].freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :projects, dependent: :destroy
  has_many :project_slug_aliases, dependent: :destroy
  has_many :statuses, dependent: :destroy
  has_many :item_types, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :api_keys, dependent: :destroy

  validates :name, presence: true

  after_create :seed_default_statuses
  after_create :seed_default_item_types

  # @return [Status, nil] first open-category status, used as the default for new items
  def default_status
    statuses.where(category: "open").order(:position).first
  end

  private

  def seed_default_statuses
    DEFAULT_STATUSES.each_with_index do |attributes, index|
      statuses.create!(name: attributes[:name], category: attributes[:category], position: index + 1)
    end
  end

  def seed_default_item_types
    DEFAULT_ITEM_TYPES.each_with_index do |attributes, index|
      item_types.create!(name: attributes[:name], color: attributes[:color], position: index + 1)
    end
  end
end
