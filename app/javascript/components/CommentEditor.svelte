<script>
  // Click-to-edit for a single comment body, mirroring the item-notes flow in
  // ItemEditor: rendered rich text until clicked, then a rhino editor with
  // Save/Cancel that PATCHes JSON and swaps the fresh HTML back in.
  import focusRhino from "../focus_rhino"

  let { comment: initialComment, updateUrl, blobUrlTemplate, directUploadUrl } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let comment = $state(initialComment)
  let editing = $state(false)
  let saving = $state(false)

  // svelte-ignore state_referenced_locally -- the id never changes after mount
  const inputId = `comment-body-input-${initialComment.id}`

  function begin(event) {
    if (event.target.closest("a")) return
    editing = true
  }

  async function save() {
    saving = true
    const body = document.getElementById(inputId)?.value ?? ""
    const response = await fetch(updateUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ comment: { body } }),
    }).catch(() => null)
    saving = false

    if (response?.ok) {
      comment = await response.json()
      editing = false
      return
    }

    const errors = response ? (await response.json().catch(() => null))?.errors : null
    document.dispatchEvent(
      new CustomEvent("toast", {
        detail: { type: "alert", message: errors?.join(", ") ?? "Couldn't save the comment — check your connection." },
      })
    )
  }
</script>

{#if editing}
  <div class="field">
    <input type="hidden" id={inputId} value={comment.body_trix}>
    <rhino-editor
      input={inputId}
      data-blob-url-template={blobUrlTemplate}
      data-direct-upload-url={directUploadUrl}
      use:focusRhino
    ></rhino-editor>
  </div>
  <div class="buttons">
    <button type="button" class="button is-primary is-small" onclick={save} disabled={saving}>Save comment</button>
    <button type="button" class="button is-small" onclick={() => (editing = false)} disabled={saving}>Cancel</button>
  </div>
{:else}
  <div
    class="content comment-body item-editable"
    role="button"
    tabindex="0"
    title="Click to edit this comment"
    onclick={begin}
    onkeydown={(event) => { if (event.key === "Enter" && !event.target.closest("a")) editing = true }}
  >
    {@html comment.body_html}
  </div>
{/if}
