class Status < ApplicationRecord
  CATEGORIES = %w[open in_progress done].freeze

  belongs_to :organization
  has_many :items, dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(:position) }
end
