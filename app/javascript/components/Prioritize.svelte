<script>
  import { fade } from "svelte/transition"
  import ItemFilters from "./ItemFilters.svelte"

  let {
    createUrl,
    refreshUrl,
    prioritiesUrl,
    pair: initialPair,
    nextPair: initialNextPair,
    count: initialCount,
    total: initialTotal,
    remaining: initialRemaining,
    pinned: initialPinned,
    pinnedCount: initialPinnedCount,
    reviewCount: initialReviewCount,
    reviewUrl,
    itemTypes,
    allTags,
    statuses,
    doneStatusId,
  } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let pair = $state(initialPair)
  // The pair after the shown one, fetched ahead (PROJ-64) so a vote can advance
  // the display instantly while the comparison records in the background. Null
  // when none is ready yet (first vote, the tail of the run) or after a context
  // change until the next server response refills it.
  // svelte-ignore state_referenced_locally -- same
  let preloaded = $state(initialNextPair ?? null)
  // svelte-ignore state_referenced_locally -- same
  let count = $state(initialCount)
  // Pairs the current context could yield, and how many are still uncompared —
  // drives the progress line and the "all compared" completion state.
  // svelte-ignore state_referenced_locally -- same
  let total = $state(initialTotal ?? 0)
  // svelte-ignore state_referenced_locally -- same
  let remaining = $state(initialRemaining ?? 0)
  let busy = $state(false)
  // A record POST is in flight. Kept apart from `busy`: an optimistic vote leaves
  // the freshly shown pair fully interactive (busy stays false) while it records,
  // but secondary controls — skip, pin, filters — must still wait on it.
  let recording = $state(false)
  // One vote queued because it landed mid-record; replayed once the record
  // settles. Extra clicks beyond the first are dropped rather than stacked.
  let pendingVote = null
  let pairKey = $state(0)
  let refreshQueued = false

  const locked = $derived(busy || recording)

  // Candidate-pool filters, mirroring Board.svelte's set. Selection re-fetches a
  // fresh pair server-side (pair selection lives on the server) rather than
  // filtering an in-memory list, but the semantics match the board's exactly.
  // Session-only: a reload starts unfiltered.
  let itemType = $state("")
  let minPoints = $state(null)
  let maxPoints = $state(null)
  let selectedTags = $state([])
  let selectedStatusIds = $state([])

  const minBound = $derived(toBound(minPoints))
  const maxBound = $derived(toBound(maxPoints))
  const anyFilterActive = $derived(
    itemType !== "" ||
      minBound != null ||
      maxBound != null ||
      selectedTags.length > 0 ||
      selectedStatusIds.length > 0
  )

  // Every possible pair in the current context has been compared: the flow is
  // done rather than merely empty (which would mean too few items / no matches).
  const complete = $derived(pair == null && total > 0 && remaining === 0)

  // The anchored item (full object so its title shows even when no opponent is
  // left) and its running comparison total, both synced from server responses.
  // Seeded from props so ?pinned_item_id=… deep links (the item page's
  // "Prioritize this" button) start pinned.
  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let pinnedItem = $state(initialPinned ?? null)
  // svelte-ignore state_referenced_locally -- same
  let pinnedCount = $state(initialPinnedCount ?? 0)

  // Per-item notes state, reset with every new pair: whether the clamped notes
  // actually overflow (drives the toggle) and whether they are expanded.
  let expanded = $state({})
  let overflowing = $state({})

  // Cards show key + title + actions (PROJ-70) — judging by title is the fast
  // path. Details toggles only the rendered rich-text notes; this tracks which
  // cards have them open, reset with every new pair so each pair starts at a
  // glanceable size.
  let detailsOpen = $state({})

  // The whole card records an outcome, but reading must stay safe: clicks on
  // links or the expand toggle, and click-throughs from selecting text, are
  // not votes.
  function chooseCard(event, outcome) {
    if (busy) return
    if (event.target.closest("a, .comparison-notes-toggle")) return
    if (window.getSelection()?.toString()) return
    record(outcome)
  }

  function trackOverflow(node, id) {
    const measure = () => {
      if (!expanded[id]) overflowing[id] = node.scrollHeight > node.clientHeight + 1
    }
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(node)
    return { destroy: () => observer.disconnect() }
  }

  function toBound(value) {
    return value == null || value === "" || Number.isNaN(value) ? null : Number(value)
  }

  // One source of truth for the active filters, shared by the GET refresh (query
  // params) and the POST record (JSON body) so both stay in the same set.
  function filterParams() {
    const params = {}
    if (itemType) params.item_type = itemType
    if (minBound != null) params.min_points = minBound
    if (maxBound != null) params.max_points = maxBound
    if (selectedTags.length) params.tags = selectedTags
    if (selectedStatusIds.length) params.status_ids = selectedStatusIds
    return params
  }

  function refreshRequestUrl() {
    const url = new URL(refreshUrl, window.location.origin)
    if (pinnedItem?.id) url.searchParams.set("pinned_item_id", pinnedItem.id)
    if (itemType) url.searchParams.set("item_type", itemType)
    if (minBound != null) url.searchParams.set("min_points", minBound)
    if (maxBound != null) url.searchParams.set("max_points", maxBound)
    for (const tag of selectedTags) url.searchParams.append("tags[]", tag)
    for (const id of selectedStatusIds) url.searchParams.append("status_ids[]", id)
    return url.toString()
  }

  function clearFilters() {
    itemType = ""
    minPoints = null
    maxPoints = null
    selectedTags = []
    selectedStatusIds = []
    refreshPair()
  }

  // Swap the shown pair and reset its per-pair view state (notes clamp, fade key).
  function showPair(newPair) {
    pair = newPair
    expanded = {}
    overflowing = {}
    detailsOpen = {}
    pairKey += 1
  }

  // A full context refresh (initial load, skip, filter, pin): the server's pair
  // becomes current and its lookahead seeds the preload slot.
  function applyPair(data) {
    showPair(data.pair)
    preloaded = data.next_pair ?? null
    count = data.count
    total = data.total ?? 0
    remaining = data.remaining ?? 0

    if (data.pinned_id == null) {
      pinnedItem = null
      pinnedCount = 0
    } else {
      pinnedCount = data.pinned_count ?? 0
      if (pinnedItem?.id !== data.pinned_id && data.pair) pinnedItem = data.pair[0]
    }
  }

  async function record(outcome) {
    if (!pair) return
    if (recording) {
      if (pendingVote == null) pendingVote = outcome
      return
    }

    const voted = pair

    if (preloaded) {
      // The next pair is already in hand: show it now, record in the background,
      // and refill the preload from the response. On failure, undo the advance so
      // the unrecorded vote can be retried.
      const snapshot = { count, total, remaining, pinnedCount }
      const advanced = preloaded

      showPair(advanced)
      preloaded = null
      count += 1
      if (remaining > 0) remaining -= 1
      if (pinnedItem) pinnedCount += 1

      recording = true
      const data = await postRecord(voted, outcome, advanced)
      recording = false

      if (data) {
        count = data.count
        total = data.total ?? 0
        remaining = data.remaining ?? 0
        preloaded = data.pair ?? null
        if (pinnedItem && data.pinned_count != null) pinnedCount = data.pinned_count
      } else {
        count = snapshot.count
        total = snapshot.total
        remaining = snapshot.remaining
        pinnedCount = snapshot.pinnedCount
        preloaded = pair
        showPair(voted)
        toast("alert", "That vote didn't save — try again.")
      }
    } else {
      // No lookahead yet (first vote, or the tail of the run): block until the
      // server hands back the next pair the classic way.
      busy = true
      recording = true
      const data = await postRecord(voted, outcome, null)
      recording = false
      busy = false

      if (data) applyPair(data)
      else toast("alert", "That vote didn't save — try again.")
    }

    drainAfterRecord()
  }

  // POSTs one recorded comparison. +excludePair+ is the pair the island is now
  // showing, so the returned lookahead skips it (see ComparisonsController).
  // Returns the parsed response, or null on any network/HTTP failure.
  async function postRecord(votedPair, outcome, excludePair) {
    const response = await fetch(createUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({
        item_a_id: votedPair[0].id,
        item_b_id: votedPair[1].id,
        outcome,
        pinned_item_id: pinnedItem?.id ?? null,
        exclude_pair: excludePair ? [ excludePair[0].id, excludePair[1].id ] : null,
        ...filterParams(),
      }),
    }).catch(() => null)

    if (response?.ok) return await response.json()
    return null
  }

  // After a record settles, service whatever queued while it ran: a context
  // change (skip/filter/pin) wins and drops the now-stale queued vote; otherwise
  // replay the one queued vote.
  function drainAfterRecord() {
    if (refreshQueued) {
      refreshQueued = false
      pendingVote = null
      refreshPair()
    } else if (pendingVote != null) {
      const outcome = pendingVote
      pendingVote = null
      record(outcome)
    }
  }

  // Fetches a fresh pair under the current filters and pin — used by Skip and by
  // every filter change so the shown pair always reflects the active criteria.
  // A change made while a request is in flight queues one follow-up refresh so
  // the displayed pair can't go stale relative to the selected filters.
  async function refreshPair() {
    if (busy || recording) {
      refreshQueued = true
      return
    }
    busy = true
    // The new context supersedes any vote queued against the old pair.
    pendingVote = null

    const response = await fetch(refreshRequestUrl(), { headers: { Accept: "application/json" } }).catch(() => null)
    if (response?.ok) applyPair(await response.json())
    busy = false
    drainQueuedRefresh()
  }

  function drainQueuedRefresh() {
    if (!refreshQueued) return
    refreshQueued = false
    refreshPair()
  }

  const skip = refreshPair

  async function pin(item) {
    if (locked) return
    pinnedItem = item
    pinnedCount = 0
    await skip()
  }

  async function unpin() {
    if (locked) return
    pinnedItem = null
    pinnedCount = 0
    await skip()
  }

  function toast(type, message) {
    document.dispatchEvent(new CustomEvent("toast", { detail: { type, message } }))
  }

  // Retires a stale item straight to the org's done status (a direct move, not
  // the advance-one-step pipeline) and draws a fresh pair. On failure nothing
  // changes: the item stays in the pool and the shown pair is untouched.
  async function markComplete(item) {
    if (locked || doneStatusId == null) return
    busy = true

    const response = await fetch(item.move_url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ status_id: doneStatusId }),
    }).catch(() => null)

    busy = false

    if (!response?.ok) {
      toast("alert", `Couldn't mark "${item.title}" complete.`)
      return
    }

    if (pinnedItem?.id === item.id) {
      pinnedItem = null
      pinnedCount = 0
    }

    toast("notice", `Marked "${item.title}" complete.`)
    await refreshPair()
  }

  // Quick-fill reasons for the review modal — one tap flags with that reason.
  const REVIEW_PRESETS = [ "Ambiguous title", "Needs more details", "May already be done" ]

  // How many of the project's items are set aside for review — explains a
  // thinned-out pool in the empty/completion states, with a link to the board
  // filtered to flagged items.
  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let reviewCount = $state(initialReviewCount ?? 0)

  // The item whose review modal is open (null = closed), the note being typed,
  // and whether a review POST is in flight.
  let reviewing = $state(null)
  let reviewNote = $state("")
  let reviewBusy = $state(false)

  function openReview(item) {
    if (locked) return
    reviewing = item
    reviewNote = ""
  }

  function closeReview() {
    if (reviewBusy) return
    reviewing = null
    reviewNote = ""
  }

  // Flags the shown item for review (PROJ-65) with an optional note, which drops
  // it from the pool, then draws a fresh pair. Presets pass their text straight
  // in for a one-tap flag; the note field passes whatever was typed (blank ok).
  async function submitReview(note) {
    if (!reviewing || reviewBusy) return
    reviewBusy = true
    const item = reviewing

    const response = await fetch(item.review_url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ review_note: (note ?? "").trim() }),
    }).catch(() => null)

    reviewBusy = false

    if (!response?.ok) {
      toast("alert", `Couldn't flag "${item.title}" for review.`)
      return
    }

    reviewing = null
    reviewNote = ""

    if (pinnedItem?.id === item.id) {
      pinnedItem = null
      pinnedCount = 0
    }

    // Bump the "Review queue" badge (a ReviewQueueLink island) and the local
    // set-aside count live.
    reviewCount += 1
    document.dispatchEvent(new CustomEvent("review:flagged"))
    toast("notice", `Flagged "${item.title}" for review.`)
    await refreshPair()
  }
</script>

<svelte:window
  onkeydown={(event) => {
    if (event.key === "Escape" && reviewing) closeReview()
  }}
/>

{#snippet reviewHint()}
  {#if reviewCount > 0}
    <p class="has-text-weak mt-3">
      {reviewCount} {reviewCount === 1 ? "item is" : "items are"} set aside for review —
      <a href={reviewUrl}>review {reviewCount === 1 ? "it" : "them"}</a>.
    </p>
  {/if}
{/snippet}

{#snippet choice(item, outcome)}
  {@const isPinned = pinnedItem?.id === item.id}
  {@const open = !!detailsOpen[item.id]}
  <div class="comparison-card-wrap">
    <div
      class="comparison-card"
      class:has-details={!!item.notes_html}
      role="button"
      tabindex="0"
      aria-disabled={busy}
      onclick={(event) => chooseCard(event, outcome)}
      onkeydown={(event) => {
        // Only the card itself votes on Enter/space; keydowns bubbling up from a
        // focused child (the key link, an action button, the notes toggle)
        // must not fall through to a comparison outcome.
        if (event.target !== event.currentTarget) return
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault()
          record(outcome)
        }
      }}
    >
      <span class="comparison-card-key">{item.key}</span>
      <span class="comparison-card-title">{item.title}</span>
      {#if open && item.notes_html}
        <div
          class="content comparison-notes"
          class:is-clamped={!expanded[item.id]}
          use:trackOverflow={item.id}
        >
          {@html item.notes_html}
        </div>
        {#if overflowing[item.id] || expanded[item.id]}
          <button
            type="button"
            class="comparison-notes-toggle"
            onclick={(event) => {
              event.stopPropagation()
              expanded[item.id] = !expanded[item.id]
            }}
          >
            {expanded[item.id] ? "Show less" : "Show more"}
          </button>
        {/if}
      {/if}
      <div class="comparison-card-actions">
          <a
            class="comparison-edit"
            href={item.url}
            target="_blank"
            rel="noopener"
            title="Open this item (opens in a new tab)"
            aria-label={`Open ${item.title}`}
          >
            Open
          </a>
          <button
            type="button"
            class="comparison-pin"
            class:is-pinned={isPinned}
            disabled={locked}
            aria-pressed={isPinned}
            title={isPinned ? "Unpin this item" : "Pin this item to compare it against the rest"}
            aria-label={isPinned ? `Unpin ${item.title}` : `Pin ${item.title}`}
            onclick={(event) => {
              event.stopPropagation()
              isPinned ? unpin() : pin(item)
            }}
          >
            {isPinned ? "Pinned" : "Pin"}
          </button>
          {#if doneStatusId != null}
            <button
              type="button"
              class="comparison-complete"
              disabled={locked}
              title="Move this item straight to done"
              aria-label={`Mark ${item.title} complete`}
              onclick={(event) => {
                event.stopPropagation()
                markComplete(item)
              }}
            >
              Mark complete
            </button>
          {/if}
          <button
            type="button"
            class="comparison-review"
            disabled={locked}
            title="Set this item aside for review — removes it from prioritizing"
            aria-label={`Flag ${item.title} for review`}
            onclick={(event) => {
              event.stopPropagation()
              openReview(item)
            }}
          >
            Flag for review
          </button>
        </div>
    </div>
    {#if item.notes_html}
      <button
        type="button"
        class="comparison-details-toggle"
        aria-expanded={open}
        aria-label={open ? `Hide details for ${item.title}` : `Show details for ${item.title}`}
        onclick={() => (detailsOpen[item.id] = !open)}
      >
        {open ? "Hide ▴" : "Details ▾"}
      </button>
    {/if}
  </div>
{/snippet}

<div class="filter-toolbar">
  <ItemFilters
    bind:itemType
    bind:minPoints
    bind:maxPoints
    bind:selectedTags
    bind:selectedStatusIds
    {itemTypes}
    {allTags}
    {statuses}
    onchange={refreshPair}
    onclear={clearFilters}
  />
</div>

{#if pinnedItem}
  <div class="comparison-pin-bar">
    <span class="comparison-pin-bar-label">
      <span class="tag is-primary">Pinned</span>
      <span class="comparison-pin-bar-title">{pinnedItem.title}</span>
      <span class="has-text-weak">· {pinnedCount} {pinnedCount === 1 ? "comparison" : "comparisons"}</span>
    </span>
    <button type="button" class="button is-small" disabled={locked} onclick={unpin}>Unpin</button>
  </div>
{/if}

{#if pair}
  {#key pairKey}
    <div class="comparison-pair" in:fade={{ duration: 150 }}>
      {@render choice(pair[0], "a_wins")}
      <button type="button" class="button comparison-equal" disabled={busy} onclick={() => record("draw")}>
        Equal priority
      </button>
      {@render choice(pair[1], "b_wins")}
    </div>
  {/key}

  <div class="buttons is-centered mt-4">
    <button type="button" class="button is-light" disabled={locked} onclick={skip}>Skip</button>
  </div>

  <p class="has-text-centered has-text-weak">
    {#if total > 0}
      {total - remaining} of {total} {total === 1 ? "pair" : "pairs"} compared{#if remaining > 0} · {remaining} to go{/if}
    {:else}
      {count} {count === 1 ? "comparison" : "comparisons"} recorded so far.
    {/if}
  </p>
{:else if complete && pinnedItem}
  <div class="notification is-success is-light has-text-centered">
    <p>You've compared <strong>{pinnedItem.title}</strong> against everything else here. Unpin to keep prioritizing.</p>
    <div class="buttons is-centered mt-4">
      <button type="button" class="button" disabled={locked} onclick={unpin}>Unpin</button>
    </div>
  </div>
{:else if pinnedItem}
  <div class="notification is-info is-light">
    <p>No other open items are left to compare against the pinned item. Unpin to keep prioritizing.</p>
  </div>
{:else if complete}
  <div class="notification is-success has-text-centered" in:fade={{ duration: 200 }}>
    <p class="title is-4">🎉 Every pair compared</p>
    <p>
      You've judged all {total} {total === 1 ? "pair" : "pairs"}{anyFilterActive ? " in this filtered set" : ""} —
      this backlog is fully ranked.
    </p>
    <div class="buttons is-centered mt-4">
      <a class="button is-primary" href={prioritiesUrl}>View priorities</a>
      {#if anyFilterActive}
        <button type="button" class="button" onclick={clearFilters}>Clear filters</button>
      {/if}
    </div>
    {@render reviewHint()}
  </div>
{:else if anyFilterActive}
  <div class="notification is-info is-light">
    <p>
      No pair matches your filters.
      <button type="button" class="filter-clear" onclick={clearFilters}>Clear filters</button>
    </p>
  </div>
{:else}
  <div class="notification is-info is-light">
    <p>You need at least two open items in this project to prioritize. Add or reopen some items, then come back.</p>
    {@render reviewHint()}
  </div>
{/if}

{#if reviewing}
  <div
    class="review-modal-overlay"
    role="presentation"
    onclick={closeReview}
    transition:fade={{ duration: 120 }}
  >
    <!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -- backdrop-stop only; the dialog's own controls carry the keyboard path -->
    <div class="review-modal" role="dialog" tabindex="-1" aria-modal="true" aria-label="Flag item for review" onclick={(event) => event.stopPropagation()}>
      <p class="review-modal-eyebrow">Flag for review</p>
      <p class="review-modal-item">{reviewing.title}</p>

      <p class="review-modal-label">Quick reasons — one tap</p>
      <div class="review-presets">
        {#each REVIEW_PRESETS as preset}
          <button type="button" class="review-preset" disabled={reviewBusy} onclick={() => submitReview(preset)}>
            {preset}
          </button>
        {/each}
      </div>

      <label class="review-modal-label" for="review-note">Or add a note (optional)</label>
      <textarea
        id="review-note"
        class="textarea"
        rows="3"
        placeholder="What needs a look?"
        bind:value={reviewNote}
        disabled={reviewBusy}
      ></textarea>

      <div class="review-modal-actions">
        <button type="button" class="button" disabled={reviewBusy} onclick={closeReview}>Cancel</button>
        <button type="button" class="button is-primary" disabled={reviewBusy} onclick={() => submitReview(reviewNote)}>
          Flag for review
        </button>
      </div>
    </div>
  </div>
{/if}
