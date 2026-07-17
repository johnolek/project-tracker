class Project < ApplicationRecord
  belongs_to :organization
  has_many :items, dependent: :destroy

  validates :name, presence: true
end
