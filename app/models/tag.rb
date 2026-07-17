class Tag < ApplicationRecord
  belongs_to :organization
  has_many :item_tags, dependent: :destroy
  has_many :items, through: :item_tags

  # name is citext, so uniqueness is case-insensitive at the database level
  validates :name, presence: true, uniqueness: { scope: :organization_id }
end
