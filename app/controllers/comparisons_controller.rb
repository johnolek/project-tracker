class ComparisonsController < ApplicationController
  before_action :require_login
  before_action :set_project

  def new
    @pair = next_pair
    @comparison_count = Comparison.for_project(@project).count

    respond_to do |format|
      format.html
      format.json { render json: pair_payload(pair: @pair, count: @comparison_count) }
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
        format.json { render json: pair_payload(pair: next_pair, count: Comparison.for_project(@project).count) }
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

  # @param pair [Array<Item>, nil]
  # @param count [Integer]
  # @return [Hash] the JSON the Prioritize island consumes after each action
  def pair_payload(pair:, count:)
    { pair: pair&.map(&:comparison_payload), count: count }
  end

  # Picks the project's two open items that have appeared in the fewest
  # comparisons so far, breaking ties randomly. This steers attention toward
  # under-compared items (improving ranking coverage) while the random tiebreak
  # keeps the same pair from recurring. Returns nil when there are fewer than
  # two open items.
  #
  # @return [Array<Item>, nil]
  def next_pair
    items = @project.items.not_done.includes(:status).to_a
    return nil if items.size < 2

    counts = Comparison.counts_by_item(project: @project)
    items.sort_by { |item| [ counts.fetch(item.id, 0), rand ] }.first(2)
  end
end
