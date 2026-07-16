class Project < ApplicationRecord
  belongs_to :organization
  has_many :items, dependent: :destroy

  has_secure_token :public_token

  validates :name, presence: true
end
