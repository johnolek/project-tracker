<script>
  import saveItem from "../save_item"
  import tagColorClass from "../tag_color"

  let { item: initialItem, updateUrl, statuses, itemTypes, pointOptions, allTags, parentOptions } = $props()

  const PROVENANCE_LABELS = {
    user_created: "User created",
    ai_created: "AI created",
    ai_reviewed: "AI reviewed",
  }

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let item = $state(initialItem)
  let saving = $state(false)
  let tagInput = $state("")
  let highlighted = $state(-1)
  let parentInput = $state("")
  let parentHighlighted = $state(-1)

  // Non-fibonacci estimates (API-written or legacy) keep rendering: the current
  // value joins the offered options rather than showing as blank.
  const offeredPoints = $derived(
    item.points != null && !pointOptions.includes(item.points)
      ? [...pointOptions, item.points].sort((a, b) => a - b)
      : pointOptions
  )

  const suggestions = $derived.by(() => {
    const query = tagInput.trim().toLowerCase()
    if (!query) return []
    return allTags
      .filter((tag) => tag.toLowerCase().includes(query))
      .filter((tag) => !item.tags.some((existing) => existing.toLowerCase() === tag.toLowerCase()))
      .slice(0, 8)
  })

  const currentParent = $derived(parentOptions.find((option) => option.id === item.parent_id) ?? null)

  const parentSuggestions = $derived.by(() => {
    const query = parentInput.trim().toLowerCase()
    if (!query) return []
    return parentOptions
      .filter((option) => option.id !== item.parent_id)
      .filter((option) => option.label.toLowerCase().includes(query))
      .slice(0, 8)
  })

  async function save(attrs) {
    saving = true
    const fresh = await saveItem(updateUrl, attrs)
    saving = false
    if (fresh) item = fresh
    return fresh != null
  }

  async function addTag(name) {
    const trimmed = name.trim()
    if (!trimmed) return
    if (item.tags.some((tag) => tag.toLowerCase() === trimmed.toLowerCase())) {
      tagInput = ""
      highlighted = -1
      return
    }
    if (await save({ tag_names: [...item.tags, trimmed] })) {
      tagInput = ""
      highlighted = -1
    }
  }

  function removeTag(name) {
    save({ tag_names: item.tags.filter((tag) => tag !== name) })
  }

  async function setParent(option) {
    if (await save({ parent_id: option.id })) {
      parentInput = ""
      parentHighlighted = -1
    }
  }

  function clearParent() {
    save({ parent_id: null })
  }

  // Enter with nothing highlighted picks the top match: unlike tags, a parent
  // can't be created from free text, so the query only ever narrows the list.
  function parentKeydown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      parentHighlighted = Math.min(parentHighlighted + 1, parentSuggestions.length - 1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      parentHighlighted = Math.max(parentHighlighted - 1, -1)
    } else if (event.key === "Enter") {
      event.preventDefault()
      const choice = parentHighlighted >= 0 ? parentSuggestions[parentHighlighted] : parentSuggestions[0]
      if (choice) setParent(choice)
    } else if (event.key === "Escape") {
      parentInput = ""
      parentHighlighted = -1
    }
  }

  function tagKeydown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      highlighted = Math.min(highlighted + 1, suggestions.length - 1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      highlighted = Math.max(highlighted - 1, -1)
    } else if (event.key === "Enter") {
      event.preventDefault()
      addTag(highlighted >= 0 ? suggestions[highlighted] : tagInput)
    } else if (event.key === "Escape") {
      tagInput = ""
      highlighted = -1
    }
  }

  function formatDate(epoch) {
    return new Date(epoch * 1000).toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" })
  }

  function formatStrength(value) {
    return `${value >= 0 ? "+" : ""}${value.toFixed(1)}`
  }
</script>

<aside class="box item-meta">
  <dl class="item-meta-list">
    <div class="item-meta-row">
      <dt>Status</dt>
      <dd>
        <div class="select is-small is-fullwidth">
          <select
            aria-label="Change status"
            disabled={saving}
            value={item.status_id}
            onchange={(event) => save({ status_id: Number(event.target.value) })}
          >
            {#each statuses as status (status.id)}
              <option value={status.id}>{status.name}</option>
            {/each}
          </select>
        </div>
      </dd>
    </div>

    <div class="item-meta-row">
      <dt>Type</dt>
      <dd>
        <div class="select is-small is-fullwidth">
          <select
            aria-label="Change type"
            disabled={saving}
            value={item.item_type}
            onchange={(event) => save({ item_type: event.target.value })}
          >
            {#each itemTypes as type (type)}
              <option value={type}>{type}</option>
            {/each}
          </select>
        </div>
        <span class="item-type-tag item-type-{item.item_type} mt-1">{item.item_type}</span>
      </dd>
    </div>

    <div class="item-meta-row">
      <dt>Points</dt>
      <dd>
        <div class="select is-small is-fullwidth">
          <select
            aria-label="Change points"
            disabled={saving}
            value={item.points == null ? "" : String(item.points)}
            onchange={(event) => save({ points: event.target.value === "" ? null : Number(event.target.value) })}
          >
            <option value="">No estimate</option>
            {#each offeredPoints as option (option)}
              <option value={String(option)}>{option}</option>
            {/each}
          </select>
        </div>
      </dd>
    </div>

    <div class="item-meta-row">
      <dt>Parent</dt>
      <dd>
        {#if currentParent}
          <div class="tags mb-1">
            <span class="tag parent-tag">
              <a href={currentParent.url}>{currentParent.label}</a>
              <button
                type="button"
                class="delete is-small"
                aria-label="Clear parent"
                disabled={saving}
                onclick={clearParent}
              ></button>
            </span>
          </div>
        {/if}
        <div class="tag-typeahead">
          <input
            class="input is-small"
            type="text"
            placeholder={currentParent ? "Change parent…" : "Set parent…"}
            aria-label={currentParent ? "Change parent" : "Set parent"}
            autocomplete="off"
            disabled={saving}
            bind:value={parentInput}
            onkeydown={parentKeydown}
          >
          {#if parentSuggestions.length}
            <ul class="tag-typeahead-suggestions" role="listbox" aria-label="Parent suggestions">
              {#each parentSuggestions as suggestion, index (suggestion.id)}
                <li>
                  <button
                    type="button"
                    class="tag-typeahead-option"
                    class:is-highlighted={index === parentHighlighted}
                    role="option"
                    aria-selected={index === parentHighlighted}
                    onclick={() => setParent(suggestion)}
                  >{suggestion.label}</button>
                </li>
              {/each}
            </ul>
          {/if}
        </div>
        <p class="help">Type to search this project's items.</p>
      </dd>
    </div>

    <div class="item-meta-row">
      <dt>Tags</dt>
      <dd>
        {#if item.tags.length}
          <div class="tags mb-1">
            {#each item.tags as tag (tag)}
              <span class="tag {tagColorClass(tag)}">
                {tag}
                <button
                  type="button"
                  class="delete is-small"
                  aria-label="Remove tag {tag}"
                  disabled={saving}
                  onclick={() => removeTag(tag)}
                ></button>
              </span>
            {/each}
          </div>
        {/if}
        <div class="tag-typeahead">
          <input
            class="input is-small"
            type="text"
            placeholder="Add tag…"
            aria-label="Add tag"
            autocomplete="off"
            disabled={saving}
            bind:value={tagInput}
            onkeydown={tagKeydown}
          >
          {#if suggestions.length}
            <ul class="tag-typeahead-suggestions" role="listbox" aria-label="Tag suggestions">
              {#each suggestions as suggestion, index (suggestion)}
                <li>
                  <button
                    type="button"
                    class="tag-typeahead-option"
                    class:is-highlighted={index === highlighted}
                    role="option"
                    aria-selected={index === highlighted}
                    onclick={() => addTag(suggestion)}
                  >{suggestion}</button>
                </li>
              {/each}
            </ul>
          {/if}
        </div>
        <p class="help">Enter adds; new names create a tag.</p>
      </dd>
    </div>

    <div class="item-meta-row">
      <dt>Strength</dt>
      <dd>{formatStrength(item.strength)}</dd>
    </div>

    <div class="item-meta-row">
      <dt>Provenance</dt>
      <dd>
        {PROVENANCE_LABELS[item.provenance] ?? item.provenance}
        {#if item.ai_reviewed_at}
          <span class="is-block has-text-weak">{formatDate(item.ai_reviewed_at)}</span>
        {/if}
      </dd>
    </div>

    <div class="item-meta-row">
      <dt>Created</dt>
      <dd>{formatDate(item.created_at)}</dd>
    </div>

    <div class="item-meta-row">
      <dt>Updated</dt>
      <dd>{formatDate(item.updated_at)}</dd>
    </div>
  </dl>
</aside>
