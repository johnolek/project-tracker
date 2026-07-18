<script>
  // Target picker for the relationship "Add link" form. Mounts inside the server-
  // rendered <form>, so submission and CSRF stay with Rails: the current choice
  // rides along in a hidden <input name="link[target_id]">. Uses the shared
  // Typeahead, which shows recent items on focus (options arrive recent-first).
  import Typeahead from "./Typeahead.svelte"

  let { name, options = [], placeholder = "Search items…" } = $props()

  let selected = $state(null)
</script>

{#if selected}
  <div class="tags mb-0">
    <span class="tag parent-tag">
      {selected.label}
      <button
        type="button"
        class="delete is-small"
        aria-label="Clear selected item"
        onclick={() => (selected = null)}
      ></button>
    </span>
  </div>
{:else}
  <Typeahead
    {options}
    {placeholder}
    ariaLabel="Link target"
    onselect={(option) => (selected = option)}
  />
{/if}

<input type="hidden" {name} value={selected?.value ?? ""}>
