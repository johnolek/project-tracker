# Fits Bradley-Terry priority strengths from pairwise comparisons.
#
# Each item carries a positive latent strength; the model's probability that
# item i is preferred over item j is strength_i / (strength_i + strength_j). We
# find the maximum-likelihood strengths with the standard MM (minorization-
# maximization) iteration of Hunter (2004) — equivalently Zermelo's algorithm —
# and report them as log-strengths centered at 0, so they are organization-
# relative and directly comparable across items.
class BradleyTerry
  # Every item is given this many pseudo-wins and pseudo-losses against a virtual
  # opponent of fixed strength 1 (the geometric-mean item). This Bayesian
  # regularization keeps undefeated items and disconnected comparison graphs from
  # diverging to +/- infinity and gently pulls sparsely-compared items toward the
  # average. It is small enough that a handful of real comparisons dominate it.
  REGULARIZATION = 1e-3

  # The virtual regularizing opponent sits at the center of the scale.
  VIRTUAL_OPPONENT_STRENGTH = 1.0

  MAX_ITERATIONS = 1_000

  # Convergence is declared once no log-strength moves more than this between
  # iterations.
  TOLERANCE = 1e-9

  # @param comparisons [Enumerable] objects responding to #item_a_id, #item_b_id
  #   and #outcome (one of "a_wins", "b_wins", "draw")
  # @return [Hash{Integer => Float}] item_id => log-strength, mean-centered at 0
  #   and ordered by item_id. Empty when there are no comparisons.
  def self.fit(comparisons:)
    new(comparisons: comparisons).fit
  end

  # @param comparisons [Enumerable] see {.fit}
  def initialize(comparisons:)
    @wins = Hash.new(0.0)
    @opponents = Hash.new { |hash, key| hash[key] = Hash.new(0) }
    ingest(comparisons)
    @item_ids = @opponents.keys.sort
  end

  # @return [Hash{Integer => Float}] see {.fit}
  def fit
    return {} if @item_ids.empty?

    strengths = @item_ids.index_with { VIRTUAL_OPPONENT_STRENGTH }
    logs = log_strengths(strengths)

    MAX_ITERATIONS.times do
      next_strengths = @item_ids.index_with { |id| updated_strength(id, strengths) }
      next_logs = log_strengths(next_strengths)
      converged = max_change(logs, next_logs) < TOLERANCE
      strengths = next_strengths
      logs = next_logs
      break if converged
    end

    centered(logs)
  end

  private

  # Draws count as half a win for each side; every comparison is one game between
  # the pair, tallied symmetrically so each item knows its opponents.
  def ingest(comparisons)
    comparisons.each do |comparison|
      a = comparison.item_a_id
      b = comparison.item_b_id

      case comparison.outcome
      when "a_wins" then @wins[a] += 1.0
      when "b_wins" then @wins[b] += 1.0
      when "draw"
        @wins[a] += 0.5
        @wins[b] += 0.5
      end

      @opponents[a][b] += 1
      @opponents[b][a] += 1
    end
  end

  # One MM update: new strength = regularized wins divided by the expected-games
  # term summed over real opponents plus the virtual opponent.
  def updated_strength(id, strengths)
    numerator = @wins[id] + REGULARIZATION
    denominator = (2.0 * REGULARIZATION) / (strengths[id] + VIRTUAL_OPPONENT_STRENGTH)
    @opponents[id].each do |opponent_id, games|
      denominator += games / (strengths[id] + strengths[opponent_id])
    end
    numerator / denominator
  end

  def log_strengths(strengths)
    strengths.transform_values { |strength| Math.log(strength) }
  end

  def max_change(previous, current)
    current.keys.map { |id| (current[id] - previous[id]).abs }.max
  end

  def centered(logs)
    mean = logs.values.sum / logs.size
    logs.transform_values { |value| value - mean }
  end
end
