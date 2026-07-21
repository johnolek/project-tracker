<script>
  import saveItem from "../save_item"
  import focusRhino from "../focus_rhino"
  import hasTextSelection from "../text_selection"

  let { item: initialItem, updateUrl, blobUrlTemplate, directUploadUrl } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let item = $state(initialItem)
  let editingTitle = $state(false)
  let titleDraft = $state("")
  let editingNotes = $state(false)
  let saving = $state(false)

  // svelte-ignore state_referenced_locally -- the id never changes after mount
  const notesInputId = `item-notes-input-${initialItem.id}`

  function focusOnMount(node) {
    node.focus()
    node.select?.()
  }


  function beginTitle() {
    titleDraft = item.title
    editingTitle = true
  }

  async function saveTitle() {
    const trimmed = titleDraft.trim()
    if (!trimmed || trimmed === item.title) {
      editingTitle = false
      return
    }

    saving = true
    const fresh = await saveItem(updateUrl, { title: trimmed })
    saving = false
    if (fresh) {
      item = fresh
      editingTitle = false
      document.title = fresh.title
    }
  }

  function titleKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      saveTitle()
    } else if (event.key === "Escape") {
      editingTitle = false
    }
  }

  // Links inside rendered notes still navigate; anywhere else starts editing —
  // unless the click was really a select-drag to copy text.
  function beginNotes(event) {
    if (event.target.closest("a")) return
    if (hasTextSelection()) return
    editingNotes = true
  }

  async function saveNotes() {
    saving = true
    const value = document.getElementById(notesInputId)?.value ?? ""
    const fresh = await saveItem(updateUrl, { notes: value })
    saving = false
    if (fresh) {
      item = fresh
      editingNotes = false
    }
  }
</script>

{#if editingTitle}
  <input
    class="input item-title-input mb-4"
    bind:value={titleDraft}
    use:focusOnMount
    onkeydown={titleKeydown}
    onblur={saveTitle}
    disabled={saving}
    aria-label="Item title"
  >
{:else}
  <h1 class="title mb-4">
    <button
      type="button"
      class="item-editable item-title-trigger"
      class:is-empty={!item.title}
      title="Click to edit the title"
      onclick={beginTitle}
    >{item.title || "Add a title…"}</button>
  </h1>
{/if}

{#if editingNotes}
  <div class="field">
    <input type="hidden" id={notesInputId} value={item.notes_trix}>
    <rhino-editor
      input={notesInputId}
      data-blob-url-template={blobUrlTemplate}
      data-direct-upload-url={directUploadUrl}
      use:focusRhino
    ></rhino-editor>
  </div>
  <div class="buttons">
    <button type="button" class="button is-primary is-small" onclick={saveNotes} disabled={saving}>Save notes</button>
    <button type="button" class="button is-small" onclick={() => (editingNotes = false)} disabled={saving}>Cancel</button>
  </div>
{:else}
  <div
    class="content item-notes item-editable"
    role="button"
    tabindex="0"
    title="Click to edit notes"
    onclick={beginNotes}
    onkeydown={(event) => { if (event.key === "Enter" && !event.target.closest("a")) editingNotes = true }}
  >
    {#if item.notes_html}
      {@html item.notes_html}
    {:else}
      <p class="has-text-weak">No notes yet — click to add some.</p>
    {/if}
  </div>
{/if}
