<script>
  // Shared filter toolbar for the board and the prioritize view. Parents own the
  // filter state (bound in) and its consumption: the board reacts to the bound
  // state through its own $derived pipeline, so number/search inputs take effect
  // per keystroke; prioritize reacts only through the onchange callback, which
  // fires on discrete changes (select, toggle, chip remove, clear, and a number
  // input's change event — blur/enter), keeping its server refresh off the
  // per-keystroke path. This single wiring preserves both behaviors.
  let {
    itemType = $bindable(""),
    minPoints = $bindable(null),
    maxPoints = $bindable(null),
    selectedTags = $bindable([]),
    selectedStatusIds = $bindable([]),
    query = $bindable(""),
    itemTypes = [],
    allTags = [],
    statuses,
    showQuery = false,
    hiddenCount,
    onchange = () => {},
    onclear = () => {},
    children,
  } = $props()

  let tagMenuOpen = $state(false)
  let statusMenuOpen = $state(false)

  const minBound = $derived(toBound(minPoints))
  const maxBound = $derived(toBound(maxPoints))
  // A status dropdown only earns its place when there is a real choice to make.
  const hasStatusFilter = $derived(!!statuses && statuses.length > 1)
  const anyFilterActive = $derived(
    (showQuery && query.trim() !== "") ||
      itemType !== "" ||
      minBound != null ||
      maxBound != null ||
      selectedTags.length > 0 ||
      selectedStatusIds.length > 0
  )

  function toBound(value) {
    return value == null || value === "" || Number.isNaN(value) ? null : Number(value)
  }

  function statusName(id) {
    return statuses?.find((status) => status.id === id)?.name ?? ""
  }

  function toggleTag(tag) {
    selectedTags = selectedTags.includes(tag)
      ? selectedTags.filter((candidate) => candidate !== tag)
      : [...selectedTags, tag]
    onchange()
  }

  function toggleStatus(id) {
    selectedStatusIds = selectedStatusIds.includes(id)
      ? selectedStatusIds.filter((candidate) => candidate !== id)
      : [...selectedStatusIds, id]
    onchange()
  }

  function clickOutside(node, onOutside) {
    const handler = (event) => {
      if (!node.contains(event.target)) onOutside()
    }
    document.addEventListener("click", handler)
    return { destroy: () => document.removeEventListener("click", handler) }
  }
</script>

{#if showQuery}
  <div class="control filter-toolbar-search">
    <input
      class="input is-small"
      type="search"
      placeholder="Filter cards by title…"
      aria-label="Filter cards by title"
      bind:value={query}
    >
  </div>
{/if}

<div class="control">
  <div class="select is-small">
    <select bind:value={itemType} {onchange} aria-label="Filter by item type">
      <option value="">All types</option>
      {#each itemTypes as type (type.name)}
        <option value={type.name}>{type.name}</option>
      {/each}
    </select>
  </div>
</div>

<div class="field has-addons filter-points-range" role="group" aria-label="Filter by point range">
  <div class="control">
    <input
      class="input is-small filter-points-input"
      type="number"
      min="0"
      placeholder="min"
      aria-label="Minimum points"
      bind:value={minPoints}
      {onchange}
    >
  </div>
  <div class="control">
    <input
      class="input is-small filter-points-input"
      type="number"
      min="0"
      placeholder="max"
      aria-label="Maximum points"
      bind:value={maxPoints}
      {onchange}
    >
  </div>
</div>

{#if allTags.length}
  <div class="dropdown" class:is-active={tagMenuOpen} use:clickOutside={() => (tagMenuOpen = false)}>
    <div class="dropdown-trigger">
      <button
        type="button"
        class="button is-small"
        aria-haspopup="true"
        aria-expanded={tagMenuOpen}
        onclick={() => (tagMenuOpen = !tagMenuOpen)}
      >
        <span>Tags{selectedTags.length ? ` (${selectedTags.length})` : ""}</span>
        <span class="filter-caret" aria-hidden="true">▾</span>
      </button>
    </div>
    <div class="dropdown-menu" role="menu">
      <div class="dropdown-content">
        {#each allTags as tag (tag)}
          <button
            type="button"
            class="dropdown-item"
            class:is-active={selectedTags.includes(tag)}
            role="menuitemcheckbox"
            aria-checked={selectedTags.includes(tag)}
            onclick={() => toggleTag(tag)}
          >
            {selectedTags.includes(tag) ? "✓ " : ""}{tag}
          </button>
        {/each}
      </div>
    </div>
  </div>
{/if}

{#if hasStatusFilter}
  <div class="dropdown" class:is-active={statusMenuOpen} use:clickOutside={() => (statusMenuOpen = false)}>
    <div class="dropdown-trigger">
      <button
        type="button"
        class="button is-small"
        aria-haspopup="true"
        aria-expanded={statusMenuOpen}
        onclick={() => (statusMenuOpen = !statusMenuOpen)}
      >
        <span>Status{selectedStatusIds.length ? ` (${selectedStatusIds.length})` : ""}</span>
        <span class="filter-caret" aria-hidden="true">▾</span>
      </button>
    </div>
    <div class="dropdown-menu" role="menu">
      <div class="dropdown-content">
        {#each statuses as status (status.id)}
          <button
            type="button"
            class="dropdown-item"
            class:is-active={selectedStatusIds.includes(status.id)}
            role="menuitemcheckbox"
            aria-checked={selectedStatusIds.includes(status.id)}
            onclick={() => toggleStatus(status.id)}
          >
            {selectedStatusIds.includes(status.id) ? "✓ " : ""}{status.name}
          </button>
        {/each}
      </div>
    </div>
  </div>
{/if}

{@render children?.()}

{#if anyFilterActive}
  <div class="filter-active-filters">
    {#each selectedTags as tag (tag)}
      <span class="tag is-small is-primary filter-chip">
        {tag}
        <button
          type="button"
          class="delete is-small"
          aria-label={`Remove ${tag} tag filter`}
          onclick={() => toggleTag(tag)}
        ></button>
      </span>
    {/each}
    {#each selectedStatusIds as id (id)}
      <span class="tag is-small is-primary filter-chip">
        {statusName(id)}
        <button
          type="button"
          class="delete is-small"
          aria-label={`Remove ${statusName(id)} status filter`}
          onclick={() => toggleStatus(id)}
        ></button>
      </span>
    {/each}
    <button type="button" class="filter-clear" onclick={onclear}>
      {#if hiddenCount > 0}{hiddenCount} hidden — {/if}Clear filters
    </button>
  </div>
{/if}
