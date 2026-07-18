<script>
  // Shared typeahead: a filtering text input over a caller-supplied option list.
  // Options show on focus (in the order passed — callers pass most-recent-first to
  // surface recent items/tags without typing) and narrow as you type. Selection and
  // free-text creation are reported through callbacks so the component stays state-
  // free about what a choice means. Styling reuses the .tag-typeahead classes.
  let {
    options = [],
    placeholder = "",
    ariaLabel = placeholder,
    disabled = false,
    allowCreate = false,
    maxSuggestions = 8,
    onselect,
    oncreate,
  } = $props()

  let query = $state("")
  let focused = $state(false)
  let highlighted = $state(-1)
  let blurTimer

  const filtered = $derived.by(() => {
    const q = query.trim().toLowerCase()
    const base = q ? options.filter((option) => option.label.toLowerCase().includes(q)) : options
    return base.slice(0, maxSuggestions)
  })

  const canCreate = $derived(
    allowCreate &&
      query.trim().length > 0 &&
      !filtered.some((option) => option.label.toLowerCase() === query.trim().toLowerCase())
  )

  const open = $derived(focused && (filtered.length > 0 || canCreate))

  function reset() {
    query = ""
    highlighted = -1
    focused = false
  }

  function choose(option) {
    onselect?.(option)
    reset()
  }

  function create() {
    const text = query.trim()
    if (!text) return
    oncreate?.(text)
    reset()
  }

  function keydown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      highlighted = Math.min(highlighted + 1, filtered.length - 1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      highlighted = Math.max(highlighted - 1, -1)
    } else if (event.key === "Enter") {
      event.preventDefault()
      if (highlighted >= 0 && filtered[highlighted]) choose(filtered[highlighted])
      else if (canCreate) create()
      else if (filtered[0]) choose(filtered[0])
    } else if (event.key === "Escape") {
      reset()
    }
  }

  // Options use onmousedown/preventDefault so clicking one doesn't blur the input
  // before the click lands; the timer is a belt-and-suspenders close on real blur.
  function onFocus() {
    clearTimeout(blurTimer)
    focused = true
  }

  function onBlur() {
    blurTimer = setTimeout(() => { focused = false }, 120)
  }
</script>

<div class="tag-typeahead">
  <input
    class="input is-small"
    type="text"
    {placeholder}
    aria-label={ariaLabel}
    autocomplete="off"
    {disabled}
    bind:value={query}
    onkeydown={keydown}
    onfocus={onFocus}
    onblur={onBlur}
  >
  {#if open}
    <ul class="tag-typeahead-suggestions" role="listbox" aria-label={`${ariaLabel} suggestions`}>
      {#each filtered as option, index (option.value)}
        <li>
          <button
            type="button"
            class="tag-typeahead-option"
            class:is-highlighted={index === highlighted}
            role="option"
            aria-selected={index === highlighted}
            onmousedown={(event) => event.preventDefault()}
            onclick={() => choose(option)}
          >{option.label}</button>
        </li>
      {/each}
      {#if canCreate}
        <li>
          <button
            type="button"
            class="tag-typeahead-option"
            role="option"
            onmousedown={(event) => event.preventDefault()}
            onclick={create}
          >Create “{query.trim()}”</button>
        </li>
      {/if}
    </ul>
  {/if}
</div>
