class ComparisonsController < ApplicationController
  before_action :require_login
  before_action :set_project

  def new
    @pinned = pinned_item
    @selection = selection(pinned: @pinned)
    @comparison_count = Comparison.for_project(@project).count

    respond_to do |format|
      format.html
      format.json { render json: pair_payload(selection: @selection, count: @comparison_count, pinned: @pinned) }
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
          selection = selection(pinned: pinned, exclude: excluded_pairs)
          render json: pair_payload(selection: selection, count: Comparison.for_project(@project).count, pinned: pinned)
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
    @project = find_project!(params[:project_id] || params[:id])
  end

  # Resolves the optional pin from +params[:pinned_item_id]+. A pin is honored
  # only when it names an open item of this project; anything missing, done, or
  # foreign is silently ignored so pairing falls back to the normal heuristic.
  #
  # @return [Item, nil]
  def pinned_item
    return nil if params[:pinned_item_id].blank?

    @project.items.not_done.not_needing_review.find_by(id: params[:pinned_item_id])
  end

  # Candidate-pool filters, read identically from GET query params (new) and the
  # POST JSON body (create) so the flow never leaves the filtered set. Each
  # criterion is validated and normalized here; anything unparseable is dropped
  # so a bad value narrows nothing rather than emptying the pool.
  #
  # @return [Hash]
  def filters
    @filters ||= {
      item_type: item_type_names.include?(params[:item_type]) ? params[:item_type] : nil,
      min_points: points_bound(params[:min_points]),
      max_points: points_bound(params[:max_points]),
      tags: Array(params[:tags]).filter_map { |name| name.to_s.strip.presence },
      exclude_tags: Array(params[:exclude_tags]).filter_map { |name| name.to_s.strip.presence },
      status_ids: requested_status_ids
    }
  end

  # Mirrors Board.svelte's matchesFilters so both filtering surfaces share
  # semantics: item type is exact; a minimum floor excludes unpointed items
  # while a maximum ceiling passes them; multi-selected tags AND together;
  # carrying any excluded tag rejects (PROJ-69); and a status multi-select
  # restricts the pool (empty means the whole not_done set).
  #
  # @param item [Item]
  # @return [Boolean]
  def matches_filters?(item)
    return false if filters[:item_type] && item.item_type != filters[:item_type]
    return false if filters[:min_points] && (item.points.nil? || item.points < filters[:min_points])
    return false if filters[:max_points] && item.points && item.points > filters[:max_points]
    return false if filters[:tags].any? && (filters[:tags] - item.tags.map(&:name)).any?
    return false if filters[:exclude_tags].any? && (filters[:exclude_tags] & item.tags.map(&:name)).any?
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

  # @return [Array<String>] the organization's configured item-type names
  def item_type_names
    @item_type_names ||= current_organization.item_types.pluck(:name)
  end

  # @param selection [Hash] the result of +selection+ (pair + lookahead + progress)
  # @param count [Integer]
  # @param pinned [Item, nil] the anchored item, echoed back so the client stays
  #   in sync (nil when no valid pin is active)
  # @return [Hash] the JSON the Prioritize island consumes after each action
  def pair_payload(selection:, count:, pinned: nil)
    PrioritizePayload.build(project: @project, selection: selection, count: count, pinned: pinned)
  end

  # The pair the client already has on screen, echoed back on a POST so the
  # lookahead we return skips it — otherwise the freshly recorded vote could
  # surface the very pair the island is currently showing as its next preload.
  #
  # @return [Array<Array(Integer, Integer)>] a one-element list of the id pair,
  #   or empty when no valid pair was supplied
  def excluded_pairs
    ids = Array(params[:exclude_pair]).filter_map { |id| Integer(id.to_s, exception: false) }
    ids.size == 2 && ids.first != ids.last ? [ ids ] : []
  end

  # Picks the next uncompared pair and reports progress toward covering them all.
  #
  # Each unordered pair is only worth comparing once (Bradley-Terry gains nothing
  # from a repeat), so already-compared pairs are excluded and the flow ends when
  # none remain — that exhaustion is the completion state the client celebrates.
  #
  # The pool is the project's not_done items narrowed by the active filters. With
  # no pin, the pair is the least-compared uncompared combination (the random
  # tiebreak spreads coverage). With a +pinned+ item, it's anchored as item A
  # against its least-compared uncompared opponent from the filtered pool: an
  # explicit pin is honored even when it no longer matches the filters, but its
  # opponents still respect them.
  #
  # +total+ is the number of pairs the current context could yield and
  # +remaining+ how many are still uncompared, so the client can show progress
  # and know when it's done (remaining zero with total positive).
  #
  # Alongside the chosen +pair+ we return +next_pair+, the pick that would come
  # after it, so the island can preload it and advance a vote without waiting for
  # the round-trip (PROJ-64). +exclude+ drops already-shown pairs from the pick so
  # a post-vote refresh doesn't hand back the pair the island is still displaying.
  #
  # @param pinned [Item, nil]
  # @param exclude [Array<Array(Integer, Integer)>] id pairs to skip when picking
  # @return [Hash{Symbol => Object}] { pair:, next_pair:, total:, remaining: }
  # Never enumerates the pair space (PROJ-83): progress is arithmetic over the
  # compared-pair rows, and picking walks items least-compared-first, taking
  # the first partner not already faced. Fairness matches the old sum-of-counts
  # pair ranking in spirit: under-compared items surface first, ties break
  # randomly.
  def selection(pinned: nil, exclude: [])
    items = @project.items.not_done.not_needing_review.includes(:status, :tags).select { |item| matches_filters?(item) }
    counts = Comparison.counts_by_item(project: @project)
    skip = exclude.map { |first, second| pair_key(first, second) }.to_set

    if pinned
      faced = Comparison.partner_ids(item: pinned)
      opponents = items.reject { |item| item.id == pinned.id }
      available = opponents.reject { |item| faced.include?(item.id) }
      ranked = available.sort_by { |item| [ counts.fetch(item.id, 0), rand ] }

      first, second = pick_two(ranked, skip) { |item| pair_key(pinned.id, item.id) }

      {
        pair: first && [ pinned, first ],
        next_pair: second && [ pinned, second ],
        total: opponents.size,
        remaining: available.size
      }
    else
      candidate_ids = items.map(&:id).to_set
      faced = Hash.new { |hash, id| hash[id] = Set.new }
      compared_within = 0
      Comparison.compared_pairs(project: @project).each do |low, high|
        next unless candidate_ids.include?(low) && candidate_ids.include?(high)

        faced[low] << high
        faced[high] << low
        compared_within += 1
      end

      ranked = items.sort_by { |item| [ counts.fetch(item.id, 0), rand ] }
      first = next_uncompared_pair(ranked, faced, skip)
      second = first && next_uncompared_pair(ranked, faced, skip + [ pair_key(first[0].id, first[1].id) ])
      total = items.size * (items.size - 1) / 2

      {
        pair: first,
        next_pair: second,
        total: total,
        remaining: total - compared_within
      }
    end
  end

  # The first eligible pair in fairness order: for each item (least compared
  # first), the first later-ranked partner it hasn't faced whose pair isn't
  # skipped. Returns immediately in the common case; only a nearly fully
  # compared pool scans far, and then it's set probes, not pair allocation.
  #
  # @param ranked [Array<Item>] items sorted least-compared-first
  # @param faced [Hash{Integer => Set<Integer>}] adjacency of compared ids
  # @param skip [Set<Array(Integer, Integer)>]
  # @return [Array(Item, Item), nil]
  def next_uncompared_pair(ranked, faced, skip)
    ranked.each_with_index do |first, index|
      ranked.drop(index + 1).each do |second|
        next if faced[first.id].include?(second.id)
        next if skip.include?(pair_key(first.id, second.id))

        return [ first, second ]
      end
    end
    nil
  end

  # The first two entries of an already-ranked list whose pair keys aren't in
  # +skip+ (and where the second differs from the first). The block maps an entry
  # to its unordered pair key.
  #
  # @param ranked [Array]
  # @param skip [Set<Array(Integer, Integer)>]
  # @return [Array(Object, Object)] first and second picks, either may be nil
  def pick_two(ranked, skip)
    first = ranked.find { |entry| !skip.include?(yield(entry)) }
    return [ nil, nil ] unless first

    skip_first = skip + [ yield(first) ]
    second = ranked.find { |entry| !skip_first.include?(yield(entry)) }
    [ first, second ]
  end

  # @return [Array(Integer, Integer)] the two ids as a sorted tuple
  def pair_key(first, second)
    first < second ? [ first, second ] : [ second, first ]
  end
end
