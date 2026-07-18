module ApplicationHelper
  # Renders an item's type as a colored chip. The class hooks match the Svelte
  # board card (item-type-tag + item-type-<type>) so the board and the ERB
  # renderings share one coloring pass; the color itself lives in the stylesheet.
  #
  # @param item [Item]
  # @return [ActiveSupport::SafeBuffer]
  def item_type_tag(item)
    tag.span(item.item_type, class: "item-type-tag item-type-#{item.item_type}")
  end

  # Deterministic color class for a tag name. djb2 hash (seed 5381, times 33)
  # over the lowercased UTF-8 bytes, masked to 32 bits, mod eight buckets. Must
  # stay identical to app/javascript/tag_color.js so a tag gets the same
  # .tag-color-N in ERB and on the Svelte board.
  #
  # @param name [String]
  # @return [String]
  def tag_color_class(name:)
    hash = 5381
    name.to_s.downcase.each_byte { |byte| hash = (hash * 33 + byte) & 0xffffffff }
    "tag-color-#{hash % 8}"
  end

  # Props for the Board Svelte island on the project page.
  #
  # @param project [Project]
  # @return [Hash]
  def board_props(project)
    {
      projectId: project.id,
      storageKey: dom_id(project, :board_sort),
      statuses: project.organization.statuses.ordered.map do |status|
        { id: status.id, name: status.name, new_item_url: new_project_item_path(project, status_id: status.id) }
      end,
      items: project.items.includes(:tags).map(&:board_payload)
    }
  end

  # Props for the Prioritize Svelte island.
  #
  # @param project [Project]
  # @param pair [Array<Item>, nil]
  # @param count [Integer]
  # @return [Hash]
  def prioritize_props(project:, pair:, count:, pinned: nil)
    organization = project.organization
    {
      createUrl: project_comparisons_path(project),
      refreshUrl: prioritize_project_path(project, format: :json),
      pair: pair&.map(&:comparison_payload),
      count: count,
      pinned: pinned&.comparison_payload,
      pinnedCount: pinned ? Comparison.counts_by_item(project: project).fetch(pinned.id, 0) : 0,
      itemTypes: Item::ITEM_TYPES,
      allTags: project.items.not_done.joins(:tags).distinct.order("tags.name").pluck("tags.name"),
      statuses: organization.statuses.where.not(category: "done").ordered.map { |status| { id: status.id, name: status.name } },
      doneStatusId: organization.statuses.where(category: "done").ordered.first&.id
    }
  end

  # Props for the ItemEditor island (inline title + notes editing).
  #
  # @param project [Project]
  # @param item [Item]
  # @return [Hash]
  def item_editor_props(project:, item:)
    {
      item: item.detail_payload,
      updateUrl: project_item_path(project, item),
      blobUrlTemplate: rails_service_blob_url(":signed_id", ":filename"),
      directUploadUrl: rails_direct_uploads_url
    }
  end

  # Props for the ItemSidebar island (inline status/type/points/tags editing).
  #
  # @param project [Project]
  # @param item [Item]
  # @return [Hash]
  def item_sidebar_props(project:, item:)
    organization = project.organization
    {
      item: item.detail_payload,
      updateUrl: project_item_path(project, item),
      statuses: organization.statuses.ordered.map { |status| { id: status.id, name: status.name } },
      itemTypes: Item::ITEM_TYPES,
      pointOptions: Item::POINT_OPTIONS,
      allTags: organization.tags.order(:name).pluck(:name)
    }
  end

  # Server flash mapped to props for the Toasts island. The api_key_token key is
  # skipped: the API keys settings view renders that token inline itself, and it
  # must never surface as a toast.
  #
  # @param flash [ActionDispatch::Flash::FlashHash]
  # @return [Hash]
  def toast_props(flash)
    toasts = flash.reject { |type, _message| type == "api_key_token" }
                  .map { |type, message| { type: type, message: message } }
    { toasts: toasts }
  end

  # @return [Array<Array(String, String)>] label/value pairs for a status category select
  def status_category_options
    Status::CATEGORIES.map { |category| [ status_category_label(category), category ] }
  end

  # @param category [String] one of Status::CATEGORIES
  # @return [String] the humanized category label
  def status_category_label(category)
    category.humanize
  end
end
