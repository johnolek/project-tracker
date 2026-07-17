class Organization < ApplicationRecord
  DEFAULT_STATUSES = [
    { name: "New", category: "open" },
    { name: "In Progress", category: "in_progress" },
    { name: "Needs Verification", category: "in_progress" },
    { name: "Completed", category: "done" }
  ].freeze

  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :projects, dependent: :destroy
  has_many :statuses, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :api_keys, dependent: :destroy

  validates :name, presence: true

  after_create :seed_default_statuses

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
end
