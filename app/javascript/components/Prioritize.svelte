<script>
  import { fade } from "svelte/transition"

  let { createUrl, refreshUrl, pair: initialPair, count: initialCount, pinned: initialPinned, pinnedCount: initialPinnedCount } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let pair = $state(initialPair)
  // svelte-ignore state_referenced_locally -- same
  let count = $state(initialCount)
  let busy = $state(false)
  let pairKey = $state(0)

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

  function pinnedRefreshUrl() {
    const id = pinnedItem?.id
    if (!id) return refreshUrl

    const url = new URL(refreshUrl, window.location.origin)
    url.searchParams.set("pinned_item_id", id)
    return url.toString()
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
      }),
    }).catch(() => null)

    if (response?.ok) applyPair(await response.json())
    busy = false
  }

  async function skip() {
    if (busy) return
    busy = true

    const response = await fetch(pinnedRefreshUrl(), { headers: { Accept: "application/json" } }).catch(() => null)
    if (response?.ok) applyPair(await response.json())
    busy = false
  }

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
{:else if pinnedItem}
  <div class="notification is-info is-light">
    <p>No other open items are left to compare against the pinned item. Unpin to keep prioritizing.</p>
  </div>
{:else}
  <div class="notification is-info is-light">
    <p>You need at least two open items in this project to prioritize. Add or reopen some items, then come back.</p>
  </div>
{/if}
