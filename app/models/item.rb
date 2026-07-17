class Item < ApplicationRecord
  ITEM_TYPES = %w[bug task enhancement idea].freeze

  has_rich_text :notes

  belongs_to :project
  belongs_to :status
  has_many :comments, dependent: :destroy
  has_many :comparisons_as_item_a, class_name: "Comparison", foreign_key: :item_a_id, dependent: :destroy, inverse_of: :item_a
  has_many :comparisons_as_item_b, class_name: "Comparison", foreign_key: :item_b_id, dependent: :destroy, inverse_of: :item_b
  has_many :item_tags, dependent: :destroy
  has_many :tags, through: :item_tags

  validates :title, presence: true
  validates :strength, presence: true, numericality: true
  validates :item_type, inclusion: { in: ITEM_TYPES }
  validates :points, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :not_done, -> { joins(:status).where.not(statuses: { category: "done" }) }

  before_validation :assign_default_status, on: :create
  before_save :apply_pending_tag_names

  after_create :broadcast_board
  after_update :broadcast_board
  after_destroy :broadcast_board

  # Refits Bradley-Terry log-strengths for every item in the organization from
  # all of its comparisons and persists them, writing with update_column so the
  # per-item board broadcast (an after_update callback) does not fire once per
  # item. Items with no comparisons are reset to the neutral 0.0.
  #
  # @param organization [Organization]
  # @return [void]
  def self.recompute_strengths(organization:)
    strengths = BradleyTerry.fit(comparisons: Comparison.for_organization(organization))

    joins(:project).where(projects: { organization_id: organization.id }).find_each do |item|
      target = strengths.fetch(item.id, 0.0)
      item.update_column(:strength, target) unless item.strength == target
    end
  end

  # @return [Array<String>] tag names ordered alphabetically, or the pending
  #   names when tag_names= has been assigned but not yet saved
  def tag_names
    return @pending_tag_names unless @pending_tag_names.nil?
    return [] if new_record?

    tags.order(:name).pluck(:name)
  end

  # Stores names to be applied on save, replacing the item's full tag set.
  # Tags are found or created in the project's organization; the citext name
  # column makes lookups case-insensitive.
  #
  # @param value [Array<String>, String] names, or one comma-separated string;
  #   entries are stripped, blanks dropped, and duplicates removed
  #   case-insensitively (first spelling wins)
  def tag_names=(value)
    names = value.is_a?(String) ? value.split(",") : Array(value)
    @pending_tag_names = names.map { |name| name.to_s.strip }.reject(&:blank?).uniq(&:downcase)
  end

  private

  def assign_default_status
    self.status ||= project&.organization&.default_status
  end

  def apply_pending_tag_names
    return if @pending_tag_names.nil?

    self.tags = @pending_tag_names.map do |name|
      Tag.find_or_create_by!(organization: project.organization, name: name)
    end
    @pending_tag_names = nil
  end

  # Re-renders the whole project board so items appear, move between status
  # groups, and disappear live on every subscribed view.
  def broadcast_board
    broadcast_replace_to(
      [ project, "items" ],
      target: ActionView::RecordIdentifier.dom_id(project, :board),
      partial: "items/board",
      locals: { project: project }
    )
  end
end
