<script>
  // Parent picker for the classic item form (PROJ-68): the shared Typeahead
  // over the project's items, writing the choice into a hidden input so the
  // plain form submit carries item[parent_id]. Mirrors the sidebar's picker
  // (chip with a clear button, browse-on-focus) without its save-on-select.
  import Typeahead from "./Typeahead.svelte"

  let { name, options = [], selectedId: initialSelectedId = null } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; prop seeds state once
  let selectedId = $state(initialSelectedId)

  const selected = $derived(options.find((option) => option.value === selectedId) ?? null)
  const availableOptions = $derived(options.filter((option) => option.value !== selectedId))
</script>

<input type="hidden" {name} value={selected ? selected.value : ""}>

{#if selected}
  <div class="tags mb-1">
    <span class="tag parent-tag">
      {selected.label}
      <button
        type="button"
        class="delete is-small"
        aria-label="Clear parent"
        onclick={() => (selectedId = null)}
      ></button>
    </span>
  </div>
{/if}

<Typeahead
  options={availableOptions}
  placeholder={selected ? "Change parent…" : "No parent"}
  ariaLabel={selected ? "Change parent" : "Set parent"}
  onselect={(option) => (selectedId = option.value)}
/>
