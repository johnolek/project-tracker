<script>
  import { fade } from "svelte/transition"

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
  let tagMenuOpen = $state(false)
  let statusMenuOpen = $state(false)

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

  function statusName(id) {
    return statuses.find((status) => status.id === id)?.name ?? ""
  }

  function toggleTag(tag) {
    selectedTags = selectedTags.includes(tag)
      ? selectedTags.filter((candidate) => candidate !== tag)
      : [...selectedTags, tag]
    refreshPair()
  }

  function toggleStatus(id) {
    selectedStatusIds = selectedStatusIds.includes(id)
      ? selectedStatusIds.filter((candidate) => candidate !== id)
      : [...selectedStatusIds, id]
    refreshPair()
  }

  function clearFilters() {
    itemType = ""
    minPoints = null
    maxPoints = null
    selectedTags = []
    selectedStatusIds = []
    refreshPair()
  }

  function clickOutside(node, onOutside) {
    const handler = (event) => {
      if (!node.contains(event.target)) onOutside()
    }
    document.addEventListener("click", handler)
    return { destroy: () => document.removeEventListener("click", handler) }
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
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault()
          record(outcome)
        }
      }}
    >
      <span class="title is-5 is-block mb-2">{item.title}</span>
      <span class="tags mb-2">
        <span class="tag">{item.item_type}</span>
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
    </div>
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
{/snippet}

<div class="prioritize-toolbar">
  <div class="control">
    <div class="select is-small">
      <select bind:value={itemType} onchange={refreshPair} aria-label="Filter by item type">
        <option value="">All types</option>
        {#each itemTypes as type (type)}
          <option value={type}>{type}</option>
        {/each}
      </select>
    </div>
  </div>

  <div class="field has-addons prioritize-points-range" role="group" aria-label="Filter by point range">
    <div class="control">
      <input
        class="input is-small prioritize-points-input"
        type="number"
        min="0"
        placeholder="min"
        aria-label="Minimum points"
        bind:value={minPoints}
        onchange={refreshPair}
      >
    </div>
    <div class="control">
      <input
        class="input is-small prioritize-points-input"
        type="number"
        min="0"
        placeholder="max"
        aria-label="Maximum points"
        bind:value={maxPoints}
        onchange={refreshPair}
      >
    </div>
  </div>

  {#if allTags.length}
    <div class="dropdown" class:is-active={tagMenuOpen} use:clickOutside={() => (tagMenuOpen = false)}>
      <div class="dropdown-trigger">
        <button
          type="button"
          class="button is-small"
          aria-haspopup="true"
          aria-expanded={tagMenuOpen}
          onclick={() => (tagMenuOpen = !tagMenuOpen)}
        >
          <span>Tags{selectedTags.length ? ` (${selectedTags.length})` : ""}</span>
          <span class="prioritize-caret" aria-hidden="true">▾</span>
        </button>
      </div>
      <div class="dropdown-menu" role="menu">
        <div class="dropdown-content">
          {#each allTags as tag (tag)}
            <button
              type="button"
              class="dropdown-item"
              class:is-active={selectedTags.includes(tag)}
              role="menuitemcheckbox"
              aria-checked={selectedTags.includes(tag)}
              onclick={() => toggleTag(tag)}
            >
              {selectedTags.includes(tag) ? "✓ " : ""}{tag}
            </button>
          {/each}
        </div>
      </div>
    </div>
  {/if}

  {#if statuses.length > 1}
    <div class="dropdown" class:is-active={statusMenuOpen} use:clickOutside={() => (statusMenuOpen = false)}>
      <div class="dropdown-trigger">
        <button
          type="button"
          class="button is-small"
          aria-haspopup="true"
          aria-expanded={statusMenuOpen}
          onclick={() => (statusMenuOpen = !statusMenuOpen)}
        >
          <span>Status{selectedStatusIds.length ? ` (${selectedStatusIds.length})` : ""}</span>
          <span class="prioritize-caret" aria-hidden="true">▾</span>
        </button>
      </div>
      <div class="dropdown-menu" role="menu">
        <div class="dropdown-content">
          {#each statuses as status (status.id)}
            <button
              type="button"
              class="dropdown-item"
              class:is-active={selectedStatusIds.includes(status.id)}
              role="menuitemcheckbox"
              aria-checked={selectedStatusIds.includes(status.id)}
              onclick={() => toggleStatus(status.id)}
            >
              {selectedStatusIds.includes(status.id) ? "✓ " : ""}{status.name}
            </button>
          {/each}
        </div>
      </div>
    </div>
  {/if}

  {#if anyFilterActive}
    <div class="prioritize-active-filters">
      {#each selectedTags as tag (tag)}
        <span class="tag is-small is-primary prioritize-filter-chip">
          {tag}
          <button
            type="button"
            class="delete is-small"
            aria-label={`Remove ${tag} tag filter`}
            onclick={() => toggleTag(tag)}
          ></button>
        </span>
      {/each}
      {#each selectedStatusIds as id (id)}
        <span class="tag is-small is-primary prioritize-filter-chip">
          {statusName(id)}
          <button
            type="button"
            class="delete is-small"
            aria-label={`Remove ${statusName(id)} status filter`}
            onclick={() => toggleStatus(id)}
          ></button>
        </span>
      {/each}
      <button type="button" class="prioritize-clear-filters" onclick={clearFilters}>Clear filters</button>
    </div>
  {/if}
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
      <button type="button" class="prioritize-clear-filters" onclick={clearFilters}>Clear filters</button>
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
