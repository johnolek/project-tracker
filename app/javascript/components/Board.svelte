<script>
  import { flip } from "svelte/animate"
  import { fade } from "svelte/transition"
  import Sortable from "sortablejs"
  import consumer from "../cable"
  import matchesItemFilters from "../item_filters"
  import ItemFilters from "./ItemFilters.svelte"
  import ItemCardBody from "./ItemCardBody.svelte"

  let { projectId, storageKey, statuses, itemTypes, items: initialItems } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let items = $state(initialItems)
  let query = $state("")
  // Filters are session-only: unlike sort, they never touch localStorage, so a
  // reload starts from an unfiltered board.
  let itemType = $state("")
  let minPoints = $state(null)
  let maxPoints = $state(null)
  let selectedTags = $state([])
  // The review queue is this board filtered to flagged items (PROJ-65).
  // ?review=1 deep-links into that state (islands remount per Turbo visit, so
  // reading the URL here follows navigation).
  let reviewOnly = $state(new URLSearchParams(window.location.search).get("review") === "1")
  let sort = $state(readSort())
  // Where dragged cards were dropped, in drop order: [{ id, statusId, index }].
  // A dropped card holds that spot instead of snapping to its sorted position.
  // Session-only; choosing a sort is an explicit re-sort and clears them.
  let dropPlacements = $state([])
  let dragging = false
  let pendingMessages = []

  const SORT_OPTIONS = [
    { key: "strength", label: "Priority", defaultDirection: "desc" },
    { key: "created", label: "Date", defaultDirection: "desc" },
    { key: "points", label: "Points", defaultDirection: "asc" },
  ]

  const normalizedQuery = $derived(query.trim().toLowerCase())
  const minBound = $derived(toBound(minPoints))
  const maxBound = $derived(toBound(maxPoints))

  // Distinct tags across every board item, derived from state so the dropdown
  // tracks live cable upserts/removals without extra wiring.
  const allTags = $derived([...new Set(items.flatMap((item) => item.tags))].sort())

  // Flagged-item total for the needs-review toggle badge; derived from item
  // state, so cable upserts (flag/resolve anywhere) keep it current.
  const reviewCount = $derived(items.filter((item) => item.needs_review).length)

  const columns = $derived(
    statuses.map((status) => ({
      status,
      items: applyPlacements(
        items
          .filter((item) => item.status_id === status.id)
          .filter(matchesFilters)
          .toSorted(compareItems),
        status.id
      ),
    }))
  )

  const visibleCount = $derived(columns.reduce((sum, column) => sum + column.items.length, 0))
  const hiddenCount = $derived(items.length - visibleCount)

  function toBound(value) {
    return value == null || value === "" || Number.isNaN(value) ? null : Number(value)
  }

  // Every criterion composes with AND, including the title query; semantics
  // live in item_filters.js (shared with its unit tests and the server mirror).
  function matchesFilters(item) {
    return matchesItemFilters(item, {
      query: normalizedQuery,
      reviewOnly,
      itemType,
      minPoints: minBound,
      maxPoints: maxBound,
      tags: selectedTags,
    })
  }

  function toggleTag(tag) {
    selectedTags = selectedTags.includes(tag)
      ? selectedTags.filter((candidate) => candidate !== tag)
      : [...selectedTags, tag]
  }

  // preventDefault/stopPropagation keep a tag click on a card from following
  // the card's link; the click only toggles the shared tag filter.
  function filterByTag(event, tag) {
    event.preventDefault()
    event.stopPropagation()
    toggleTag(tag)
  }

  // Clicking a card's type chip toggles the board's type filter (the card itself
  // is a link, so swallow the event before it navigates).
  function filterByType(event, type) {
    event.preventDefault()
    event.stopPropagation()
    itemType = itemType === type ? "" : type
  }

  function clearFilters() {
    query = ""
    itemType = ""
    minPoints = null
    maxPoints = null
    selectedTags = []
    reviewOnly = false
  }

  function readSort() {
    try {
      const raw = localStorage.getItem(storageKey)
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  }

  // Re-inserts dropped cards at their drop index after filter + sort. Later
  // drops apply last so the user's most recent placement wins.
  function applyPlacements(sorted, statusId) {
    let result = sorted
    for (const placement of dropPlacements) {
      if (placement.statusId !== statusId) continue
      const from = result.findIndex((item) => item.id === placement.id)
      if (from === -1) continue
      result = [...result]
      const [item] = result.splice(from, 1)
      result.splice(Math.min(placement.index, result.length), 0, item)
    }
    return result
  }

  function recordPlacement({ id, statusId, index }) {
    dropPlacements = [...dropPlacements.filter((placement) => placement.id !== id), { id, statusId, index }]
  }

  function clearPlacement(id) {
    dropPlacements = dropPlacements.filter((placement) => placement.id !== id)
  }

  function chooseSort(option) {
    const direction =
      sort?.key === option.key && sort.direction === option.defaultDirection
        ? option.defaultDirection === "asc" ? "desc" : "asc"
        : option.defaultDirection
    sort = { key: option.key, direction }
    dropPlacements = []
    try {
      localStorage.setItem(storageKey, JSON.stringify(sort))
    } catch {
      // localStorage unavailable (private browsing); sort still applies this visit
    }
  }

  // Missing values (unpointed items) sort last regardless of direction.
  function metric(item) {
    const { key, direction } = sort ?? { key: "created", direction: "desc" }
    const value = key === "strength" ? item.strength : key === "created" ? item.created_at : item.points
    if (value == null) return Number.MAX_VALUE
    return direction === "desc" ? -value : value
  }

  function compareItems(a, b) {
    return metric(a) - metric(b) || b.id - a.id
  }

  function sortable(node) {
    const instance = Sortable.create(node, {
      group: "board",
      animation: 150,
      onStart: () => {
        dragging = true
      },
      onEnd: (event) => finishDrag(event),
    })
    return { destroy: () => instance.destroy() }
  }

  // Sortable mutates the DOM it does not own: put the card back where Svelte
  // rendered it, then move it through state so the keyed lists re-derive. The
  // drop position is recorded as a placement so the card stays where it was
  // dropped instead of jumping to its sorted slot.
  function finishDrag({ item: el, to, from, oldIndex, newIndex }) {
    dragging = false
    if (to !== from || oldIndex !== newIndex) {
      const shift = to === from && newIndex < oldIndex ? 1 : 0
      from.insertBefore(el, from.children[oldIndex + shift] ?? null)
      recordPlacement({
        id: Number(el.dataset.itemId),
        statusId: Number(to.dataset.statusId),
        index: newIndex,
      })
    }
    if (to !== from) {
      moveItem(Number(el.dataset.itemId), Number(to.dataset.statusId))
    }
    const queued = pendingMessages
    pendingMessages = []
    queued.forEach(applyMessage)
  }

  async function moveItem(itemId, statusId) {
    const item = items.find((candidate) => candidate.id === itemId)
    if (!item || item.status_id === statusId) return

    const previousStatusId = item.status_id
    item.status_id = statusId

    const response = await fetch(item.move_url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ status_id: statusId }),
    }).catch(() => null)

    if (!response?.ok) {
      item.status_id = previousStatusId
      clearPlacement(itemId)
    }
  }

  $effect(() => {
    const subscription = consumer.subscriptions.create(
      { channel: "BoardChannel", project_id: projectId },
      {
        received: (message) => {
          if (dragging) pendingMessages.push(message)
          else applyMessage(message)
        },
      }
    )
    return () => subscription.unsubscribe()
  })

  function applyMessage(message) {
    if (message.action === "upsert") {
      const index = items.findIndex((item) => item.id === message.item.id)
      if (index === -1) items.push(message.item)
      else items[index] = message.item
      // A placement only survives while the item still sits in the column it
      // was dropped into; a move from elsewhere invalidates it.
      const placement = dropPlacements.find((candidate) => candidate.id === message.item.id)
      if (placement && placement.statusId !== message.item.status_id) clearPlacement(message.item.id)
    } else if (message.action === "remove") {
      const index = items.findIndex((item) => item.id === message.id)
      if (index !== -1) items.splice(index, 1)
      clearPlacement(message.id)
    } else if (message.action === "strengths") {
      for (const item of items) {
        const value = message.strengths[item.id]
        if (value !== undefined) item.strength = value
      }
    }
  }
</script>

<div class="filter-toolbar">
  <ItemFilters
    bind:query
    bind:itemType
    bind:minPoints
    bind:maxPoints
    bind:selectedTags
    bind:reviewOnly
    showReview
    {reviewCount}
    {itemTypes}
    {allTags}
    showQuery
    {hiddenCount}
    onclear={clearFilters}
  >
    <div class="buttons has-addons board-toolbar-sort" role="group" aria-label="Sort cards">
      {#each SORT_OPTIONS as option (option.key)}
        <button
          type="button"
          class="button is-small"
          class:is-primary={sort?.key === option.key}
          aria-pressed={sort?.key === option.key}
          onclick={() => chooseSort(option)}
        >
          {option.label}{sort?.key === option.key ? (sort.direction === "asc" ? " ↑" : " ↓") : ""}
        </button>
      {/each}
    </div>
  </ItemFilters>
</div>

<div class="columns is-multiline item-board">
  {#each columns as column (column.status.id)}
    <div class="column is-one-quarter-widescreen is-half-tablet">
      <section class="box status-group">
        <header class="status-group-header">
          <h3 class="title is-6">{column.status.name}</h3>
          <a
            class="button is-small status-add"
            href={column.status.new_item_url}
            aria-label="Add item to {column.status.name}"
          >
            <span aria-hidden="true">+</span>
          </a>
        </header>
        <ul class="status-cards" data-status-id={column.status.id} use:sortable>
          {#each column.items as item (item.id)}
            <li
              class="board-card"
              data-item-id={item.id}
              animate:flip={{ duration: 200 }}
              in:fade={{ duration: 150 }}
              out:fade={{ duration: 100 }}
            >
              <a class="board-card-link" href={item.url}>
                <ItemCardBody
                  {item}
                  {itemTypes}
                  onFilterType={filterByType}
                  onFilterTag={filterByTag}
                  activeType={itemType}
                  activeTags={selectedTags}
                />
              </a>
            </li>
          {/each}
        </ul>
        {#if column.items.length === 0}
          <p class="has-text-weak is-size-7">Nothing here yet.</p>
        {/if}
      </section>
    </div>
  {/each}
</div>
