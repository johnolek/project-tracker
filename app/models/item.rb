class Item < ApplicationRecord
  ITEM_TYPES = %w[bug task enhancement idea].freeze

  # Estimates offered by the UI (fibonacci up to 13). Not a validation: the API
  # may still write other positive integers, and such values keep rendering.
  POINT_OPTIONS = [ 1, 2, 3, 5, 8, 13 ].freeze

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
  before_create :assign_number
  before_save :apply_pending_tag_names

  after_create_commit { broadcast_board_change(action: "upsert") }
  after_update_commit { broadcast_board_change(action: "upsert") }
  after_destroy_commit { broadcast_board_change(action: "remove") }

  # Refits Bradley-Terry log-strengths for every item in the organization from
  # all of its comparisons and persists them, writing with update_column so the
  # per-item board broadcast (an update callback) does not fire once per item.
  # Boards instead get one bulk "strengths" message per affected project.
  # Items with no comparisons are reset to the neutral 0.0.
  #
  # @param organization [Organization]
  # @return [void]
  def self.recompute_strengths(organization:)
    strengths = BradleyTerry.fit(comparisons: Comparison.for_organization(organization))
    changed = Hash.new { |hash, project| hash[project] = {} }

    joins(:project).includes(:project).where(projects: { organization_id: organization.id }).find_each do |item|
      target = strengths.fetch(item.id, 0.0)
      next if item.strength == target

      item.update_column(:strength, target)
      changed[item.project][item.id] = target
    end

    changed.each do |project, values|
      BoardChannel.broadcast_to(project, { action: "strengths", strengths: values })
    end
  end

  # Human-readable Jira-style reference composed from the project slug and the
  # item's per-project sequence number, e.g. "PROJ-12". Stable for the item's
  # lifetime: slugs freeze once items exist and numbers are never reused.
  #
  # @return [String]
  def key
    "#{project.slug}-#{number}"
  end

  # JSON shape the Board Svelte island renders, both as initial props and as
  # live "upsert" messages over BoardChannel.
  #
  # @return [Hash]
  def board_payload
    {
      id: id,
      key: key,
      title: title,
      item_type: item_type,
      points: points,
      strength: strength,
      status_id: status_id,
      created_at: created_at.to_i,
      tags: tags.sort_by(&:name).map(&:name),
      url: Rails.application.routes.url_helpers.project_item_path(project_id, id),
      move_url: Rails.application.routes.url_helpers.move_project_item_path(project_id, id)
    }
  end

  # JSON shape the item-detail islands (ItemEditor/ItemSidebar) render and
  # receive back after every inline save. notes_html is the rendered rich text
  # for display; notes_trix seeds the rhino editor when editing begins.
  #
  # @return [Hash]
  def detail_payload
    board_payload.merge(
      notes_html: notes.present? ? notes.to_s : "",
      notes_trix: notes.body&.to_trix_html.to_s,
      updated_at: updated_at.to_i
    )
  end

  # JSON shape the Prioritize Svelte island renders for a candidate card.
  # Notes ship as rendered rich-text HTML; the island clamps and expands them
  # client-side rather than the server truncating markup.
  #
  # @return [Hash]
  def comparison_payload
    {
      id: id,
      title: title,
      item_type: item_type,
      points: points,
      notes_html: notes.present? ? notes.to_s : ""
    }
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

  def assign_number
    self.number ||= project.claim_next_item_number!
  end

  def apply_pending_tag_names
    return if @pending_tag_names.nil?

    self.tags = @pending_tag_names.map do |name|
      Tag.find_or_create_by!(organization: project.organization, name: name)
    end
    @pending_tag_names = nil
  end

  # Pushes this item's change to every subscribed board so cards appear, move
  # between status groups, and disappear live.
  def broadcast_board_change(action:)
    payload = action == "remove" ? { action: action, id: id } : { action: action, item: board_payload }
    BoardChannel.broadcast_to(project, payload)
  end
end
