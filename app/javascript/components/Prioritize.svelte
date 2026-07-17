<script>
  import { fade } from "svelte/transition"

  let { createUrl, refreshUrl, pair: initialPair, count: initialCount } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let pair = $state(initialPair)
  // svelte-ignore state_referenced_locally -- same
  let count = $state(initialCount)
  let busy = $state(false)
  let pairKey = $state(0)

  // The anchored item (full object so its title shows even when no opponent is
  // left) and its running comparison total, both synced from server responses.
  let pinnedItem = $state(null)
  let pinnedCount = $state(0)

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
    <button type="button" class="comparison-card" disabled={busy} onclick={() => record(outcome)}>
      <span class="title is-5 is-block mb-2">{item.title}</span>
      <span class="tags mb-2">
        <span class="tag">{item.item_type}</span>
        {#if item.points}<span class="tag">Points: {item.points}</span>{/if}
      </span>
      {#if item.notes}
        <span class="is-block has-text-weak">{item.notes}</span>
      {/if}
    </button>
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
