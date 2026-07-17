module ApplicationHelper
  # Props for the Board Svelte island on the project page.
  #
  # @param project [Project]
  # @return [Hash]
  def board_props(project)
    {
      projectId: project.id,
      storageKey: dom_id(project, :board_sort),
      statuses: project.organization.statuses.ordered.map { |status| { id: status.id, name: status.name } },
      items: project.items.includes(:tags).map(&:board_payload)
    }
  end

  # Props for the Prioritize Svelte island.
  #
  # @param project [Project]
  # @param pair [Array<Item>, nil]
  # @param count [Integer]
  # @return [Hash]
  def prioritize_props(project:, pair:, count:)
    {
      createUrl: project_comparisons_path(project),
      refreshUrl: prioritize_project_path(project, format: :json),
      pair: pair&.map(&:comparison_payload),
      count: count
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
end
