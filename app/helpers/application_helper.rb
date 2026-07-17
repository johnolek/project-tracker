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
end
