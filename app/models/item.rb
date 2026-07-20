class Item < ApplicationRecord
  # The consolidation of task + enhancement into feature (PROJ-43) kept older
  # writers working: API clients and CLI docs in other repos may still send the
  # retired names, which are folded into their replacement on assignment.
  LEGACY_ITEM_TYPES = { "task" => "feature", "enhancement" => "feature" }.freeze

  # Where the item was created, mirroring Comment::SOURCES: "web" is a person
  # in a browser session, "api" is Claude/an LLM driving the JSON API.
  SOURCES = %w[web api].freeze

  # Estimates offered by the UI (fibonacci up to 13). Not a validation: the API
  # may still write other positive integers, and such values keep rendering.
  POINT_OPTIONS = [ 1, 2, 3, 5, 8, 13 ].freeze

  has_rich_text :notes

  belongs_to :project
  belongs_to :status
  belongs_to :parent, class_name: "Item", optional: true, inverse_of: :children
  has_many :children, -> { order(:number) }, class_name: "Item", foreign_key: :parent_id,
           inverse_of: :parent, dependent: :nullify
  has_many :outgoing_links, class_name: "ItemLink", foreign_key: :source_id,
           inverse_of: :source, dependent: :destroy
  has_many :incoming_links, class_name: "ItemLink", foreign_key: :target_id,
           inverse_of: :target, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :comparisons_as_item_a, class_name: "Comparison", foreign_key: :item_a_id, dependent: :destroy, inverse_of: :item_a
  has_many :comparisons_as_item_b, class_name: "Comparison", foreign_key: :item_b_id, dependent: :destroy, inverse_of: :item_b
  has_many :item_tags, dependent: :destroy
  has_many :tags, through: :item_tags

  validates :title, presence: true
  validates :strength, presence: true, numericality: true
  validates :source, inclusion: { in: SOURCES }
  validates :points, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :item_type_configured_for_organization
  validate :parent_in_same_project
  validate :parent_not_circular

  scope :not_done, -> { joins(:status).where.not(statuses: { category: "done" }) }

  # Items flagged for review (PROJ-65) are set aside during prioritizing: they
  # leave the comparison pool until the flag is cleared, and gather in the
  # review queue. review_requested_at doubles as the flag and the "since when".
  scope :needs_review, -> { where.not(review_requested_at: nil) }
  scope :not_needing_review, -> { where(review_requested_at: nil) }

  before_validation :assign_default_status, on: :create
  before_create :assign_number
  before_save :apply_pending_tag_names
  # Cascaded comparison destroys skip their per-record refit (PROJ-78); one
  # refit here re-ranks the remaining items. prepend: true captures the flag
  # before dependent: :destroy wipes the comparisons. A project cascade skips
  # even this: its comparisons only ever connected its own (deleted) items, so
  # other projects' fits are unaffected.
  before_destroy :remember_had_comparisons, prepend: true
  after_destroy :recompute_strengths_after_cascade,
                if: -> { @had_comparisons && !destroyed_by_association }

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

  # URLs address items by their human key ("PROJ-3"). Legacy numeric-id URLs
  # still resolve via find_item! in ApplicationController, since keys contain a
  # dash and ids never do.
  #
  # @return [String]
  def to_param
    key
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
      needs_review: needs_review?,
      review_note: review_note,
      tags: tags.sort_by(&:name).map(&:name),
      url: Rails.application.routes.url_helpers.project_item_path(project, self),
      move_url: Rails.application.routes.url_helpers.move_project_item_path(project, self)
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
      provenance: provenance,
      ai_reviewed_at: ai_reviewed_at&.to_i,
      review_requested_at: review_requested_at&.to_i,
      updated_at: updated_at.to_i,
      parent_id: parent_id
    )
  end

  # Parent chain from the immediate parent up to the root. Guards against a
  # corrupted cycle in the data so rendering can never loop forever.
  #
  # @return [Array<Item>]
  def ancestors
    chain = []
    node = parent
    while node && node.id != id && chain.none? { |seen| seen.id == node.id }
      chain << node
      node = node.parent
    end
    chain
  end

  # Ids of every item below this one in the parent tree, any depth.
  #
  # @return [Array<Integer>]
  def descendant_ids
    return [] if new_record?

    sql = self.class.sanitize_sql_array([ <<~SQL, id ])
      WITH RECURSIVE descendants AS (
        SELECT id FROM items WHERE parent_id = ?
        UNION ALL
        SELECT items.id FROM items JOIN descendants ON items.parent_id = descendants.id
      )
      SELECT id FROM descendants
    SQL
    self.class.connection.select_values(sql)
  end

  # Link rows bucketed for display, each as the ItemLink paired with the other
  # endpoint: :blocks (this item blocks the other), :blocked_by (the other
  # blocks this item), :relates_to (symmetric, either stored direction).
  # Buckets sort by the other item's key.
  #
  # @return [Hash{Symbol => Array<Array(ItemLink, Item)>}]
  def grouped_links
    {
      blocks: outgoing_links.select { |link| link.kind == "blocks" }.map { |link| [ link, link.target ] },
      blocked_by: incoming_links.select { |link| link.kind == "blocks" }.map { |link| [ link, link.source ] },
      relates_to: outgoing_links.select { |link| link.kind == "relates_to" }.map { |link| [ link, link.target ] } +
        incoming_links.select { |link| link.kind == "relates_to" }.map { |link| [ link, link.source ] }
    }.transform_values { |pairs| pairs.sort_by { |_link, other| [ other.project.slug, other.number ] } }
  end

  # Same-project items eligible to become this item's parent: everything except
  # the item itself and its descendants (either would create a cycle).
  #
  # @return [ActiveRecord::Relation<Item>]
  def parent_candidates
    scope = project.items.includes(:project).order(:number)
    return scope if new_record?

    scope.where.not(id: [ id, *descendant_ids ])
  end

  # JSON shape the Prioritize Svelte island renders for a candidate card.
  # Notes ship as rendered rich-text HTML; the island clamps and expands them
  # client-side rather than the server truncating markup.
  #
  # @return [Hash]
  def comparison_payload
    {
      id: id,
      key: key,
      title: title,
      item_type: item_type,
      points: points,
      strength: strength,
      tags: tags.sort_by(&:name).map(&:name),
      notes_html: notes.present? ? notes.to_s : "",
      url: Rails.application.routes.url_helpers.project_item_path(project, self),
      move_url: Rails.application.routes.url_helpers.move_project_item_path(project, self),
      review_url: Rails.application.routes.url_helpers.review_project_item_path(project, self)
    }
  end

  # @param value [String, Symbol, nil] a current type or a retired alias
  #   (task/enhancement), which is stored as its consolidated replacement.
  #   Types are lowercase by fiat (PROJ-77) — ItemType downcases its names and
  #   the denormalized copy here follows, so every comparison (rename cascade,
  #   delete guard, API filter) is plain string equality.
  def item_type=(value)
    resolved = LEGACY_ITEM_TYPES.fetch(value.to_s, value)
    super(resolved.is_a?(String) ? resolved.downcase : resolved)
  end

  # @return [Organization, nil] the organization this item belongs to, reached
  #   through its project (nil only for an item without a project)
  def organization
    project&.organization
  end

  # @return [String, nil] the hex color of this item's configured type, or nil
  #   when the type isn't found (e.g. no organization yet)
  def item_type_color
    return nil if item_type.blank? || organization.nil?

    organization.item_types.detect { |type| type.name.casecmp?(item_type) }&.color
  end

  # @return [Boolean] true when the item was created through the JSON API
  #   (machine-created) rather than the web UI
  def from_api?
    source == "api"
  end

  # @return [Boolean] whether the item is currently flagged for review
  def needs_review?
    review_requested_at.present?
  end

  # Flags the item for review with an optional note (blank is allowed — the flag
  # itself is the signal). Idempotent on the timestamp: editing the note on an
  # already-flagged item keeps the original flag time (mirroring ai_reviewed_at).
  #
  # @param note [String, nil]
  # @return [void]
  def flag_for_review!(note: nil)
    update!(review_requested_at: review_requested_at || Time.current, review_note: note.presence)
  end

  # Clears the review flag and any note, returning the item to the pool.
  #
  # @return [void]
  def clear_review!
    update!(review_requested_at: nil, review_note: nil)
  end

  # @return [String] the provenance state shown in the UI and API:
  #   "ai_created" (born through the API), "ai_reviewed" (person-created, then
  #   revised and signed off by an LLM), or "user_created" (untouched by AI)
  def provenance
    return "ai_created" if from_api?

    ai_reviewed_at? ? "ai_reviewed" : "user_created"
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

  def remember_had_comparisons
    @had_comparisons = comparisons_as_item_a.exists? || comparisons_as_item_b.exists?
    true
  end

  def recompute_strengths_after_cascade
    organization = project&.organization
    Item.recompute_strengths(organization: organization) if organization
  end

  # Item types are per-organization data (PROJ-47), so validity is inclusion in
  # the organization's configured type names. Both sides are lowercase by
  # construction (PROJ-77), so this is plain membership. Skipped when the
  # organization can't be determined (no project yet): other validations
  # surface that, and there's no vocabulary to check against.
  def item_type_configured_for_organization
    return if item_type.blank?

    names = organization&.item_types&.map(&:name)
    return if names.nil? || names.include?(item_type)

    errors.add(:item_type, "is not a configured type for this organization")
  end

  def parent_in_same_project
    return if parent.nil? || parent.project_id == project_id

    errors.add(:parent, "must belong to the same project")
  end

  # Rejects a parent assignment that would close a loop: the item itself or
  # anything already below it in the tree. Walks up from the proposed parent
  # with a seen-set so even corrupted data can't hang the validation.
  def parent_not_circular
    return if parent.nil? || new_record?

    seen = Set.new
    node = parent
    while node
      if node.id == id
        errors.add(:parent, "can't be the item itself or one of its sub-items")
        return
      end
      break if seen.include?(node.id)

      seen << node.id
      node = node.parent
    end
  end

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
