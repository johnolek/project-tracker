<script>
  import saveItem from "../save_item"
  import tagColorClass from "../tag_color"
  import itemTypeStyle from "../item_type_style"
  import Typeahead from "./Typeahead.svelte"

  let { item: initialItem, updateUrl, statuses, itemTypes, pointOptions, allTags, parentOptions } = $props()

  const PROVENANCE_LABELS = {
    user_created: "User created",
    ai_created: "AI created",
    ai_reviewed: "AI reviewed",
  }

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let item = $state(initialItem)
  let saving = $state(false)

  // Non-fibonacci estimates (API-written or legacy) keep rendering: the current
  // value joins the offered options rather than showing as blank.
  const offeredPoints = $derived(
    item.points != null && !pointOptions.includes(item.points)
      ? [...pointOptions, item.points].sort((a, b) => a - b)
      : pointOptions
  )

  const currentParent = $derived(parentOptions.find((option) => option.id === item.parent_id) ?? null)

  // Options for the shared Typeahead (it filters on input and reveals the list
  // on focus). Parent excludes the current parent; tags exclude ones already set.
  const parentTypeaheadOptions = $derived(
    parentOptions
      .filter((option) => option.id !== item.parent_id)
      .map((option) => ({ value: option.id, label: option.label }))
  )

  const tagTypeaheadOptions = $derived(
    allTags
      .filter((tag) => !item.tags.some((existing) => existing.toLowerCase() === tag.toLowerCase()))
      .map((tag) => ({ value: tag, label: tag }))
  )

  async function save(attrs) {
    saving = true
    const fresh = await saveItem(updateUrl, attrs)
    saving = false
    if (fresh) item = fresh
    return fresh != null
  }

  function addTag(name) {
    const trimmed = name.trim()
    if (!trimmed) return
    if (item.tags.some((tag) => tag.toLowerCase() === trimmed.toLowerCase())) return
    save({ tag_names: [...item.tags, trimmed] })
  }

  function removeTag(name) {
    save({ tag_names: item.tags.filter((tag) => tag !== name) })
  }

  function setParent(option) {
    save({ parent_id: option.value })
  }

  function clearParent() {
    save({ parent_id: null })
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
            {#each itemTypes as type (type.name)}
              <option value={type.name}>{type.name}</option>
            {/each}
          </select>
        </div>
        <span class="item-type-tag mt-1" style={itemTypeStyle(itemTypes, item.item_type)}>{item.item_type}</span>
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
        <Typeahead
          options={parentTypeaheadOptions}
          placeholder={currentParent ? "Change parent…" : "Set parent…"}
          ariaLabel={currentParent ? "Change parent" : "Set parent"}
          disabled={saving}
          onselect={setParent}
        />
        <p class="help">Click to see this project's items, or type to search.</p>
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
        <Typeahead
          options={tagTypeaheadOptions}
          placeholder="Add tag…"
          ariaLabel="Add tag"
          allowCreate
          disabled={saving}
          onselect={(option) => addTag(option.value)}
          oncreate={addTag}
        />
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
