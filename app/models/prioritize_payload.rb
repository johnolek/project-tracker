# The one selection payload the Prioritize island consumes — both as its
# initial props (ApplicationHelper#prioritize_props) and as every JSON refresh
# or vote response (ComparisonsController#pair_payload). One builder, one key
# spelling, so a field added for one path can't silently miss the other
# (PROJ-80).
module PrioritizePayload
  # @param project [Project]
  # @param selection [Hash] ComparisonsController#selection result
  #   (pair + next_pair lookahead + total/remaining progress)
  # @param count [Integer] comparisons recorded in the project
  # @param pinned [Item, nil] the anchored item (nil when no valid pin is
  #   active); the client shows it as pair[0], so only the id and its
  #   comparison count travel
  # @return [Hash]
  def self.build(project:, selection:, count:, pinned: nil)
    {
      pair: selection[:pair]&.map(&:comparison_payload),
      next_pair: selection[:next_pair]&.map(&:comparison_payload),
      count: count,
      total: selection[:total],
      remaining: selection[:remaining],
      pinned_id: pinned&.id,
      pinned_count: pinned && Comparison.counts_by_item(project: project).fetch(pinned.id, 0)
    }
  end
end
