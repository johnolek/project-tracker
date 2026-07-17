<script>
  import { fade } from "svelte/transition"

  let { createUrl, refreshUrl, pair: initialPair, count: initialCount } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let pair = $state(initialPair)
  // svelte-ignore state_referenced_locally -- same
  let count = $state(initialCount)
  let busy = $state(false)
  let pairKey = $state(0)

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
      body: JSON.stringify({ item_a_id: pair[0].id, item_b_id: pair[1].id, outcome }),
    }).catch(() => null)

    if (response?.ok) {
      const data = await response.json()
      pair = data.pair
      count = data.count
      pairKey += 1
    }
    busy = false
  }

  async function skip() {
    if (busy) return
    busy = true

    const response = await fetch(refreshUrl, { headers: { Accept: "application/json" } }).catch(() => null)
    if (response?.ok) {
      const data = await response.json()
      pair = data.pair
      count = data.count
      pairKey += 1
    }
    busy = false
  }
</script>

{#snippet choice(item, outcome)}
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
{/snippet}

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
{:else}
  <div class="notification is-info is-light">
    <p>You need at least two open items in this project to prioritize. Add or reopen some items, then come back.</p>
  </div>
{/if}
