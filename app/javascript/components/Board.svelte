<script>
  import { flip } from "svelte/animate"
  import { fade } from "svelte/transition"
  import Sortable from "sortablejs"
  import consumer from "../cable"

  let { projectId, storageKey, statuses, items: initialItems } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let items = $state(initialItems)
  let query = $state("")
  let sort = $state(readSort())
  let dragging = false
  let pendingMessages = []

  const SORT_OPTIONS = [
    { key: "strength", label: "Priority", defaultDirection: "desc" },
    { key: "created", label: "Date", defaultDirection: "desc" },
    { key: "points", label: "Points", defaultDirection: "asc" },
  ]

  const normalizedQuery = $derived(query.trim().toLowerCase())
  const columns = $derived(
    statuses.map((status) => ({
      status,
      items: items
        .filter((item) => item.status_id === status.id)
        .filter((item) => !normalizedQuery || item.title.toLowerCase().includes(normalizedQuery))
        .toSorted(compareItems),
    }))
  )

  function readSort() {
    try {
      const raw = localStorage.getItem(storageKey)
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  }

  function chooseSort(option) {
    const direction =
      sort?.key === option.key && sort.direction === option.defaultDirection
        ? option.defaultDirection === "asc" ? "desc" : "asc"
        : option.defaultDirection
    sort = { key: option.key, direction }
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

  function formatStrength(value) {
    return `${value >= 0 ? "+" : ""}${value.toFixed(1)}`
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
  // rendered it, then move it through state so the keyed lists re-derive.
  // Column position within a list is always derived from the sort, so only the
  // target status matters.
  function finishDrag({ item: el, to, from, oldIndex, newIndex }) {
    dragging = false
    if (to !== from || oldIndex !== newIndex) {
      const shift = to === from && newIndex < oldIndex ? 1 : 0
      from.insertBefore(el, from.children[oldIndex + shift] ?? null)
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

    if (!response?.ok) item.status_id = previousStatusId
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
    } else if (message.action === "remove") {
      const index = items.findIndex((item) => item.id === message.id)
      if (index !== -1) items.splice(index, 1)
    } else if (message.action === "strengths") {
      for (const item of items) {
        const value = message.strengths[item.id]
        if (value !== undefined) item.strength = value
      }
    }
  }
</script>

<div class="field">
  <div class="control">
    <input
      class="input"
      type="search"
      placeholder="Filter cards by title…"
      aria-label="Filter cards by title"
      bind:value={query}
    >
  </div>
</div>

<div class="field">
  <div class="buttons has-addons" role="group" aria-label="Sort cards">
    {#each SORT_OPTIONS as option (option.key)}
      <button
        type="button"
        class="button"
        class:is-primary={sort?.key === option.key}
        aria-pressed={sort?.key === option.key}
        onclick={() => chooseSort(option)}
      >
        {option.label}{sort?.key === option.key ? (sort.direction === "asc" ? " ↑" : " ↓") : ""}
      </button>
    {/each}
  </div>
</div>

<div class="columns is-multiline item-board">
  {#each columns as column (column.status.id)}
    <div class="column is-one-quarter-widescreen is-half-tablet">
      <section class="box status-group">
        <h3 class="title is-6">{column.status.name}</h3>
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
                <span class="board-card-title">{item.title}</span>
                <span class="board-card-strength tag is-small" title="Priority strength">{formatStrength(item.strength)}</span>
                <small class="has-text-weak">({item.item_type}{item.points ? `, ${item.points} pts` : ""})</small>
                {#if item.tags.length}
                  <span class="tags mt-1">
                    {#each item.tags as tag (tag)}
                      <span class="tag is-small">{tag}</span>
                    {/each}
                  </span>
                {/if}
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
