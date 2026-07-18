<script>
  import { fade } from "svelte/transition"
  import ItemFilters from "./ItemFilters.svelte"
  import itemTypeStyle from "../item_type_style"

  let {
    createUrl,
    refreshUrl,
    pair: initialPair,
    count: initialCount,
    pinned: initialPinned,
    pinnedCount: initialPinnedCount,
    itemTypes,
    allTags,
    statuses,
    doneStatusId,
  } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let pair = $state(initialPair)
  // svelte-ignore state_referenced_locally -- same
  let count = $state(initialCount)
  let busy = $state(false)
  let pairKey = $state(0)
  let refreshQueued = false

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

  function applyPair(data) {
    pair = data.pair
    count = data.count
    expanded = {}
    overflowing = {}

    if (data.pinned_id == null) {
      pinnedItem = null
      pinnedCount = 0
    } else {
      pinnedCount = data.pinned_count ?? 0
      if (pinnedItem?.id !== data.pinned_id && data.pair) pinnedItem = data.pair[0]
    }

    pairKey += 1
  }

  async function record(outcome) {
    if (busy || !pair) return
    busy = true

    const response = await fetch(createUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({
        item_a_id: pair[0].id,
        item_b_id: pair[1].id,
        outcome,
        pinned_item_id: pinnedItem?.id ?? null,
        ...filterParams(),
      }),
    }).catch(() => null)

    if (response?.ok) applyPair(await response.json())
    busy = false
    drainQueuedRefresh()
  }

  // Fetches a fresh pair under the current filters and pin — used by Skip and by
  // every filter change so the shown pair always reflects the active criteria.
  // A change made while a request is in flight queues one follow-up refresh so
  // the displayed pair can't go stale relative to the selected filters.
  async function refreshPair() {
    if (busy) {
      refreshQueued = true
      return
    }
    busy = true

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
    if (busy) return
    pinnedItem = item
    pinnedCount = 0
    await skip()
  }

  async function unpin() {
    if (busy) return
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
    if (busy || doneStatusId == null) return
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
</script>

{#snippet choice(item, outcome)}
  {@const isPinned = pinnedItem?.id === item.id}
  <div class="comparison-card-wrap">
    <div
      class="comparison-card"
      role="button"
      tabindex="0"
      aria-disabled={busy}
      onclick={(event) => chooseCard(event, outcome)}
      onkeydown={(event) => {
        // Only the card itself votes on Enter/space; keydowns bubbling up from a
        // focused child (the key link, the complete button, the notes toggle)
        // must not fall through to a comparison outcome.
        if (event.target !== event.currentTarget) return
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault()
          record(outcome)
        }
      }}
    >
      <span class="title is-5 is-block mb-2">{item.title}</span>
      <span class="tags mb-2">
        <a class="comparison-key" href={item.url} target="_blank" rel="noopener">{item.key}</a>
        <span class="item-type-tag" style={itemTypeStyle(itemTypes, item.item_type)}>{item.item_type}</span>
        {#if item.points}<span class="tag">Points: {item.points}</span>{/if}
      </span>
      {#if item.notes_html}
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
      {#if doneStatusId != null}
        <div class="comparison-card-actions">
          <button
            type="button"
            class="comparison-complete"
            disabled={busy}
            title="Move this item straight to done"
            aria-label={`Mark ${item.title} complete`}
            onclick={(event) => {
              event.stopPropagation()
              markComplete(item)
            }}
          >
            Mark complete
          </button>
        </div>
      {/if}
    </div>
    <div class="comparison-corner-actions">
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
        disabled={busy}
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
    </div>
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
    <button type="button" class="button is-small" disabled={busy} onclick={unpin}>Unpin</button>
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
    <button type="button" class="button is-light" disabled={busy} onclick={skip}>Skip</button>
  </div>

  <p class="has-text-centered has-text-weak">
    {count} {count === 1 ? "comparison" : "comparisons"} recorded so far.
  </p>
{:else if anyFilterActive}
  <div class="notification is-info is-light">
    <p>
      No pair matches your filters.
      <button type="button" class="filter-clear" onclick={clearFilters}>Clear filters</button>
    </p>
  </div>
{:else if pinnedItem}
  <div class="notification is-info is-light">
    <p>No other open items are left to compare against the pinned item. Unpin to keep prioritizing.</p>
  </div>
{:else}
  <div class="notification is-info is-light">
    <p>You need at least two open items in this project to prioritize. Add or reopen some items, then come back.</p>
  </div>
{/if}
