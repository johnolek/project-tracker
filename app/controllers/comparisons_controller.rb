class ComparisonsController < ApplicationController
  before_action :require_login
  before_action :set_project

  def new
    @pinned = pinned_item
    @pair = next_pair(pinned: @pinned)
    @comparison_count = Comparison.for_project(@project).count

    respond_to do |format|
      format.html
      format.json { render json: pair_payload(pair: @pair, count: @comparison_count, pinned: @pinned) }
    end
  end

  def create
    item_a = @project.items.find_by(id: params[:item_a_id])
    item_b = @project.items.find_by(id: params[:item_b_id])
    return head :not_found unless item_a && item_b

    comparison = Comparison.new(item_a: item_a, item_b: item_b, user: current_user, outcome: params[:outcome])

    if comparison.save
      respond_to do |format|
        format.html { redirect_to prioritize_project_path(@project), notice: "Recorded. Here's another pair." }
        format.json do
          pinned = pinned_item
          render json: pair_payload(pair: next_pair(pinned: pinned), count: Comparison.for_project(@project).count, pinned: pinned)
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to prioritize_project_path(@project), alert: comparison.errors.full_messages.to_sentence }
        format.json { render json: { errors: comparison.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_project
    @project = current_organization.projects.find(params[:project_id] || params[:id])
  end

  # Resolves the optional pin from +params[:pinned_item_id]+. A pin is honored
  # only when it names an open item of this project; anything missing, done, or
  # foreign is silently ignored so pairing falls back to the normal heuristic.
  #
  # @return [Item, nil]
  def pinned_item
    return nil if params[:pinned_item_id].blank?

    @project.items.not_done.find_by(id: params[:pinned_item_id])
  end

  # @param pair [Array<Item>, nil]
  # @param count [Integer]
  # @param pinned [Item, nil] the anchored item, echoed back so the client stays
  #   in sync (nil when no valid pin is active)
  # @return [Hash] the JSON the Prioritize island consumes after each action
  def pair_payload(pair:, count:, pinned: nil)
    {
      pair: pair&.map(&:comparison_payload),
      count: count,
      pinned_id: pinned&.id,
      pinned_count: pinned && Comparison.counts_by_item(project: @project).fetch(pinned.id, 0)
    }
  end

  # Picks the next pair of open items to compare, breaking ties randomly.
  #
  # With no pin, returns the project's two least-compared open items (steering
  # attention toward under-compared items while the random tiebreak keeps the
  # same pair from recurring). With a +pinned+ item, the pair is anchored on it
  # as item A and the opponent is the least-compared of the remaining open
  # items. Returns nil when there are too few items to form a pair.
  #
  # @param pinned [Item, nil]
  # @return [Array<Item>, nil]
  def next_pair(pinned: nil)
    items = @project.items.not_done.includes(:status).to_a
    counts = Comparison.counts_by_item(project: @project)

    if pinned
      opponents = items.reject { |item| item.id == pinned.id }
      return nil if opponents.empty?

      [ pinned, opponents.min_by { |item| [ counts.fetch(item.id, 0), rand ] } ]
    else
      return nil if items.size < 2

      items.sort_by { |item| [ counts.fetch(item.id, 0), rand ] }.first(2)
    end
  end
end
