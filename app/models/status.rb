class Status < ApplicationRecord
  CATEGORIES = %w[open in_progress done].freeze

  belongs_to :organization
  has_many :items, dependent: :restrict_with_error

  # The API addresses statuses by name and `advance` walks positions, so
  # duplicates in either would corrupt the workflow silently (PROJ-77). Name
  # uniqueness is also enforced by a functional unique index; position stays a
  # validation only, because the web reorder swaps positions pairwise with
  # update_column (a DB constraint would reject the transient state).
  validates :name, presence: true, uniqueness: { scope: :organization_id, case_sensitive: false }
  validates :position, presence: true, numericality: { only_integer: true },
                       uniqueness: { scope: :organization_id }
  validates :category, presence: true, inclusion: { in: CATEGORIES }

  scope :ordered, -> { order(:position) }
end
