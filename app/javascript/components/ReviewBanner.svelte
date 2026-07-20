<script>
  // Item-detail banner for a flagged item (PROJ-65): shows when it was flagged
  // and its note. The note is click-to-edit — a plain textarea PATCHed to the
  // same review endpoint (which keeps the original flag time) — and Resolve
  // clears the flag, removing the banner without a reload.
  import hasTextSelection from "../text_selection"

  let { note: initialNote, timeAgo, reviewUrl } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; prop seeds state once
  let note = $state(initialNote ?? "")
  let editing = $state(false)
  let draft = $state("")
  let busy = $state(false)
  let resolved = $state(false)

  function toast(type, message) {
    document.dispatchEvent(new CustomEvent("toast", { detail: { type, message } }))
  }

  function beginEdit() {
    if (hasTextSelection()) return
    draft = note
    editing = true
  }

  function focusOnMount(node) {
    node.focus()
    node.setSelectionRange(node.value.length, node.value.length)
  }

  async function saveNote() {
    if (busy) return
    busy = true

    const response = await fetch(reviewUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ review_note: draft.trim() }),
    }).catch(() => null)

    busy = false

    if (!response?.ok) {
      toast("alert", "Couldn't save the review note.")
      return
    }

    note = (await response.json()).review_note ?? ""
    editing = false
  }

  async function resolve() {
    if (busy) return
    busy = true

    const response = await fetch(reviewUrl, {
      method: "DELETE",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
    }).catch(() => null)

    busy = false

    if (!response?.ok) {
      toast("alert", "Couldn't resolve the review flag.")
      return
    }

    resolved = true
    toast("notice", "Review resolved — the item is back in the prioritization pool.")
  }
</script>

{#if !resolved}
  <div class="review-banner">
    <div class="review-banner-body">
      <p class="review-banner-label">Flagged for review · {timeAgo} ago</p>
      {#if editing}
        <textarea
          class="textarea review-banner-edit"
          rows="2"
          placeholder="What needs a look?"
          bind:value={draft}
          disabled={busy}
          use:focusOnMount
          onkeydown={(event) => {
            if (event.key === "Escape") editing = false
          }}
        ></textarea>
        <div class="review-banner-actions">
          <button type="button" class="button is-small" disabled={busy} onclick={() => (editing = false)}>Cancel</button>
          <button type="button" class="button is-small is-primary" disabled={busy} onclick={saveNote}>Save note</button>
        </div>
      {:else}
        <button
          type="button"
          class="review-banner-note"
          class:has-text-weak={!note}
          title="Edit the review note"
          onclick={beginEdit}
        >
          {note || "No note — tap to add one."}
        </button>
      {/if}
    </div>
    <button type="button" class="button is-small review-banner-resolve" disabled={busy} onclick={resolve}>
      Resolve
    </button>
  </div>
{/if}
