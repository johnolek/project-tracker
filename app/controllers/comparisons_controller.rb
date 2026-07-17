class ComparisonsController < ApplicationController
  before_action :require_login

  def new
    @pair = next_pair
    @comparison_count = Comparison.for_organization(current_organization).count
  end

  def create
    item_a = organization_items.find_by(id: params[:item_a_id])
    item_b = organization_items.find_by(id: params[:item_b_id])
    return head :not_found unless item_a && item_b

    comparison = Comparison.new(item_a: item_a, item_b: item_b, user: current_user, outcome: params[:outcome])

    if comparison.save
      redirect_to prioritize_path, notice: "Recorded. Here's another pair."
    else
      redirect_to prioritize_path, alert: comparison.errors.full_messages.to_sentence
    end
  end

  private

  def organization_items
    Item.joins(:project).where(projects: { organization_id: current_organization.id })
  end

  # Picks the two open items that have appeared in the fewest comparisons so far,
  # breaking ties randomly. This steers attention toward under-compared items
  # (improving ranking coverage) while the random tiebreak keeps the same pair
  # from recurring. Returns nil when there are fewer than two open items.
  #
  # @return [Array<Item>, nil]
  def next_pair
    items = organization_items.not_done.includes(:project, :status).to_a
    return nil if items.size < 2

    counts = Comparison.counts_by_item(organization: current_organization)
    items.sort_by { |item| [ counts.fetch(item.id, 0), rand ] }.first(2)
  end
end
