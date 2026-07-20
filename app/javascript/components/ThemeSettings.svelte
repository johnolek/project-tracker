<script>
  // Settings → Appearance (PROJ-32): scheme cards and a light/dark mode
  // switch. A pick applies to the live document immediately (the same
  // attributes the layout renders server-side) and PATCHes the preference;
  // failure reverts the document and the selection.
  let { updateUrl, colorScheme: initialScheme, themeMode: initialMode, schemes } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let scheme = $state(initialScheme)
  // svelte-ignore state_referenced_locally -- same
  let mode = $state(initialMode)
  let saving = $state(false)

  const MODES = [
    { key: "auto", label: "Auto" },
    { key: "light", label: "Light" },
    { key: "dark", label: "Dark" },
  ]

  function applyToDocument() {
    const root = document.documentElement
    root.dataset.colorScheme = scheme
    root.dataset.theme = mode
  }

  function toast(type, message) {
    document.dispatchEvent(new CustomEvent("toast", { detail: { type, message } }))
  }

  async function save(changes) {
    const previous = { scheme, mode }
    if (changes.scheme !== undefined) scheme = changes.scheme
    if (changes.mode !== undefined) mode = changes.mode
    applyToDocument()

    saving = true
    const response = await fetch(updateUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify({ user: { color_scheme: scheme, theme_mode: mode } }),
    }).catch(() => null)
    saving = false

    if (!response?.ok) {
      scheme = previous.scheme
      mode = previous.mode
      applyToDocument()
      toast("alert", "Couldn't save that appearance choice.")
    }
  }
</script>

<div class="scheme-cards" role="radiogroup" aria-label="Color scheme">
  {#each schemes as candidate (candidate.key)}
    <button
      type="button"
      class="scheme-card"
      class:is-selected={scheme === candidate.key}
      role="radio"
      aria-checked={scheme === candidate.key}
      disabled={saving}
      onclick={() => save({ scheme: candidate.key })}
    >
      <span class="scheme-card-swatches" aria-hidden="true">
        {#each candidate.swatches as swatch (swatch)}
          <span class="scheme-card-swatch" style={`background: ${swatch}`}></span>
        {/each}
      </span>
      <span class="scheme-card-label">{candidate.label}</span>
      <span class="scheme-card-description has-text-weak">{candidate.description}</span>
    </button>
  {/each}
</div>

<div class="field mt-5">
  <span class="label">Mode</span>
  <div class="buttons has-addons" role="radiogroup" aria-label="Light or dark mode">
    {#each MODES as candidate (candidate.key)}
      <button
        type="button"
        class="button is-small"
        class:is-primary={mode === candidate.key}
        role="radio"
        aria-checked={mode === candidate.key}
        disabled={saving}
        onclick={() => save({ mode: candidate.key })}
      >
        {candidate.label}
      </button>
    {/each}
  </div>
  <p class="help">Auto follows your system's light/dark preference.</p>
</div>
