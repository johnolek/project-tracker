class Project < ApplicationRecord
  SLUG_FORMAT = /\A[A-Z][A-Z0-9]{0,9}\z/
  SLUG_MAX_LENGTH = 10

  belongs_to :organization
  has_many :items, dependent: :destroy
  has_many :slug_aliases, class_name: "ProjectSlugAlias", dependent: :destroy
  has_many :embed_domains, dependent: :destroy

  normalizes :slug, with: ->(slug) { slug.strip.upcase }

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: { scope: :organization_id },
                   format: { with: SLUG_FORMAT, message: "must be 1-10 uppercase letters/digits starting with a letter" }
  validate :slug_not_reserved

  before_validation :derive_slug, on: :create
  after_update :retire_previous_slug, if: :saved_change_to_slug?

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
    while slug_taken?(candidate)
      candidate = "#{base[0, SLUG_MAX_LENGTH - suffix.to_s.length]}#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end

  # A slug is unavailable if another active project holds it or any other project
  # has retired it (reserved). Case-insensitive, matching the DB indexes.
  #
  # @param candidate [String]
  # @return [Boolean]
  def slug_taken?(candidate)
    return false if candidate.blank? || organization.nil?

    down = candidate.downcase
    organization.projects.where.not(id: id).exists?([ "lower(slug) = ?", down ]) ||
      organization.project_slug_aliases.where.not(project_id: id).exists?([ "lower(slug) = ?", down ])
  end

  # A new or changed slug must not step on another project's reserved (retired)
  # slug; collisions with active slugs are handled by the uniqueness validator.
  def slug_not_reserved
    return if slug.blank? || organization.nil?

    reserved = organization.project_slug_aliases.where.not(project_id: id)
                           .exists?([ "lower(slug) = ?", slug.downcase ])
    errors.add(:slug, "is reserved by another project") if reserved
  end

  # After a slug change, reserve the previous slug (so old references redirect
  # and no one else can claim it) and drop any reservation matching the new slug
  # (the reclaim case, where a project changes back to a slug it once used).
  def retire_previous_slug
    slug_aliases.where("lower(slug) = ?", slug.downcase).destroy_all

    previous = slug_before_last_save
    return if previous.blank?
    return if slug_aliases.exists?([ "lower(slug) = ?", previous.downcase ])

    slug_aliases.create!(slug: previous)
  end
end
