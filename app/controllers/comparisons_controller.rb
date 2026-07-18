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

  # Candidate-pool filters, read identically from GET query params (new) and the
  # POST JSON body (create) so the flow never leaves the filtered set. Each
  # criterion is validated and normalized here; anything unparseable is dropped
  # so a bad value narrows nothing rather than emptying the pool.
  #
  # @return [Hash]
  def filters
    @filters ||= {
      item_type: Item::ITEM_TYPES.include?(params[:item_type]) ? params[:item_type] : nil,
      min_points: points_bound(params[:min_points]),
      max_points: points_bound(params[:max_points]),
      tags: Array(params[:tags]).filter_map { |name| name.to_s.strip.presence },
      status_ids: requested_status_ids
    }
  end

  # Mirrors Board.svelte's matchesFilters so both filtering surfaces share
  # semantics: item type is exact; a minimum floor excludes unpointed items
  # while a maximum ceiling passes them; multi-selected tags AND together; and a
  # status multi-select restricts the pool (empty means the whole not_done set).
  #
  # @param item [Item]
  # @return [Boolean]
  def matches_filters?(item)
    return false if filters[:item_type] && item.item_type != filters[:item_type]
    return false if filters[:min_points] && (item.points.nil? || item.points < filters[:min_points])
    return false if filters[:max_points] && item.points && item.points > filters[:max_points]
    return false if filters[:tags].any? && (filters[:tags] - item.tags.map(&:name)).any?
    return false if filters[:status_ids].any? && !filters[:status_ids].include?(item.status_id)

    true
  end

  # @param value [Object]
  # @return [Integer, nil] a non-negative integer, or nil when unparseable
  def points_bound(value)
    integer = Integer(value.to_s.strip, exception: false)
    integer if integer && integer >= 0
  end

  # @return [Array<Integer>] requested status ids narrowed to this org's
  #   non-done statuses; unknown or non-numeric ids are dropped
  def requested_status_ids
    requested = Array(params[:status_ids]).filter_map { |id| Integer(id.to_s, exception: false) }
    requested & non_done_status_ids
  end

  # @return [Array<Integer>]
  def non_done_status_ids
    @non_done_status_ids ||= current_organization.statuses.where.not(category: "done").pluck(:id)
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
  # The pool is the project's not_done items narrowed by the active filters
  # (item type, points, tags, status). With no pin, returns the two
  # least-compared items in that pool (steering attention toward under-compared
  # items while the random tiebreak keeps the same pair from recurring). With a
  # +pinned+ item, the pair is anchored on it as item A while the opponent is
  # drawn from the filtered pool: an explicit pin is honored even when it no
  # longer matches the filters, but its opponents still respect them. Returns
  # nil when the pool is too small to form a pair.
  #
  # @param pinned [Item, nil]
  # @return [Array<Item>, nil]
  def next_pair(pinned: nil)
    items = @project.items.not_done.includes(:status, :tags).select { |item| matches_filters?(item) }
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
