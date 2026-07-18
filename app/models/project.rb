class Project < ApplicationRecord
  SLUG_FORMAT = /\A[A-Z][A-Z0-9]{0,9}\z/
  SLUG_MAX_LENGTH = 10

  belongs_to :organization
  has_many :items, dependent: :destroy

  normalizes :slug, with: ->(slug) { slug.strip.upcase }

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: { scope: :organization_id },
                   format: { with: SLUG_FORMAT, message: "must be 1-10 uppercase letters/digits starting with a letter" }
  validate :slug_unchangeable_once_items_exist, on: :update

  before_validation :derive_slug, on: :create

  # Projects appear in URLs by slug ("PROJ"); legacy numeric-id URLs still
  # resolve via find_project! in ApplicationController.
  #
  # @return [String]
  def to_param
    slug
  end

  # First run of alphanumerics in the name, upcased and cut to four characters
  # (e.g. "Project Tracker" -> "PROJ"), prefixed with "P" when it would not
  # start with a letter.
  #
  # @param name [String]
  # @return [String]
  def self.derive_slug(name:)
    base = name.to_s.scan(/[A-Za-z0-9]+/).first.to_s.upcase[0, 4].to_s
    base = "P#{base}"[0, SLUG_MAX_LENGTH] unless base.match?(/\A[A-Z]/)
    base
  end

  # Atomically increments the per-project item sequence and returns the claimed
  # number. UPDATE ... RETURNING makes concurrent claims safe, and the sequence
  # only ever moves forward, so numbers freed by deleted items are never reused.
  #
  # @return [Integer]
  def claim_next_item_number!
    self.class.connection.select_value(
      self.class.sanitize_sql([
        "UPDATE projects SET last_item_number = last_item_number + 1 WHERE id = ? RETURNING last_item_number", id
      ])
    ).to_i
  end

  private

  def derive_slug
    return if slug.present?

    base = self.class.derive_slug(name: name)
    return if base.blank?

    candidate = base
    suffix = 2
    while organization&.projects&.exists?(slug: candidate)
      candidate = "#{base[0, SLUG_MAX_LENGTH - suffix.to_s.length]}#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end

  # Item keys (SLUG-number) are meant to be stable references; once any item
  # has been created under a slug the slug is frozen.
  def slug_unchangeable_once_items_exist
    return unless slug_changed?

    errors.add(:slug, "can't be changed once the project has items") if items.exists?
  end
end
