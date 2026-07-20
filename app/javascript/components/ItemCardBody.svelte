<script>
  // Shared inner card content, used by the board card (Board.svelte) and the
  // prioritize comparison card (Prioritize.svelte) so both show the same detail:
  // type chip + key, title, tags-as-chips, strength, and points. The outer
  // wrapper stays with each caller (the board card is a navigating link, the
  // comparison card is a vote button). When filter callbacks are passed (the
  // board) the type/tag chips act as filter toggles; otherwise (prioritize) they
  // render as plain chips.
  import itemTypeStyle from "../item_type_style"
  import tagColorClass from "../tag_color"

  let {
    item,
    itemTypes,
    onFilterType = null,
    onFilterTag = null,
    activeType = null,
    activeTags = [],
  } = $props()

  function formatStrength(value) {
    return `${value >= 0 ? "+" : ""}${value.toFixed(1)}`
  }
</script>

<span class="board-card-top">
  {#if onFilterType}
    <span
      class="item-type-tag board-card-type"
      class:is-active-filter={activeType === item.item_type}
      style={itemTypeStyle(itemTypes, item.item_type)}
      role="button"
      tabindex="0"
      aria-pressed={activeType === item.item_type}
      title={`Filter by ${item.item_type}`}
      onclick={(event) => onFilterType(event, item.item_type)}
      onkeydown={(event) => { if (event.key === "Enter" || event.key === " ") onFilterType(event, item.item_type) }}
    >{item.item_type}</span>
  {:else}
    <span class="item-type-tag" style={itemTypeStyle(itemTypes, item.item_type)}>{item.item_type}</span>
  {/if}
  <span class="board-card-key">{item.key}</span>
</span>

{#if item.needs_review}
  <span class="board-card-review" title="Flagged for review">
    Needs review{item.review_note ? `: ${item.review_note}` : ""}
  </span>
{/if}

<span class="board-card-title">{item.title}</span>

<div class="board-card-meta">
  {#if item.tags.length}
    <span class="tags board-card-tags">
      {#each item.tags as tag (tag)}
        {#if onFilterTag}
          <span
            class="tag is-small board-card-tag {tagColorClass(tag)}"
            class:is-active-filter={activeTags.includes(tag)}
            role="button"
            tabindex="0"
            aria-pressed={activeTags.includes(tag)}
            title={`Filter by ${tag}`}
            onclick={(event) => onFilterTag(event, tag)}
            onkeydown={(event) => { if (event.key === "Enter" || event.key === " ") onFilterTag(event, tag) }}
          >{tag}</span>
        {:else}
          <span class="tag is-small board-card-tag {tagColorClass(tag)}">{tag}</span>
        {/if}
      {/each}
    </span>
  {/if}
  <span class="board-card-badges">
    <span class="board-card-strength tag is-small" title="Priority strength">{formatStrength(item.strength)}</span>
    {#if item.points}<span class="board-card-points" title="{item.points} points">{item.points}</span>{/if}
  </span>
</div>
