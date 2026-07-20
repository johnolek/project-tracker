<script>
  // Settings → Appearance (PROJ-32): scheme cards, a light/dark mode switch,
  // and a custom-scheme editor. Picks apply to the live document immediately
  // (the same attributes/variables the layout renders server-side) and PATCH
  // the preference; failure reverts the document and the selection. Custom
  // color edits preview live and persist through an explicit Save, with AA
  // contrast warnings (theme_contrast.js) that inform without blocking.
  import { buildCustomVariables, contrastWarnings } from "../theme_contrast"

  let { updateUrl, colorScheme: initialScheme, themeMode: initialMode, customColors: initialCustom, schemes } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let scheme = $state(initialScheme)
  // svelte-ignore state_referenced_locally -- same
  let mode = $state(initialMode)
  // svelte-ignore state_referenced_locally -- same
  let customColors = $state({ ...initialCustom })
  // The custom colors as last saved — live edits diverge from this until Save.
  // svelte-ignore state_referenced_locally -- same
  let savedCustomColors = $state({ ...initialCustom })
  let saving = $state(false)

  const MODES = [
    { key: "auto", label: "Auto" },
    { key: "light", label: "Light" },
    { key: "dark", label: "Dark" },
  ]

  const CUSTOM_FIELDS = [
    { key: "tint", label: "Surface tint", help: "Hue and saturation for backgrounds and borders — lightness comes from the mode." },
    { key: "primary", label: "Primary" },
    { key: "link", label: "Link" },
    { key: "info", label: "Info" },
    { key: "success", label: "Success" },
    { key: "warning", label: "Warning" },
    { key: "danger", label: "Danger" },
  ]

  const warnings = $derived(scheme === "custom" ? contrastWarnings(customColors) : [])
  const customDirty = $derived(CUSTOM_FIELDS.some(({ key }) => customColors[key] !== savedCustomColors[key]))

  function applyToDocument() {
    const root = document.documentElement
    root.dataset.colorScheme = scheme
    root.dataset.theme = mode
    if (scheme === "custom") root.setAttribute("style", buildCustomVariables(customColors))
    else root.removeAttribute("style")
  }

  function toast(type, message) {
    document.dispatchEvent(new CustomEvent("toast", { detail: { type, message } }))
  }

  async function patch(body) {
    saving = true
    const response = await fetch(updateUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
      body: JSON.stringify(body),
    }).catch(() => null)
    saving = false
    return response?.ok ?? false
  }

  async function choose(changes) {
    const previous = { scheme, mode }
    if (changes.scheme !== undefined) scheme = changes.scheme
    if (changes.mode !== undefined) mode = changes.mode
    applyToDocument()

    const payload = { color_scheme: scheme, theme_mode: mode }
    if (scheme === "custom") payload.custom_colors = customColors

    if (!(await patch({ user: payload }))) {
      scheme = previous.scheme
      mode = previous.mode
      applyToDocument()
      toast("alert", "Couldn't save that appearance choice.")
    } else if (scheme === "custom") {
      savedCustomColors = { ...customColors }
    }
  }

  function previewCustom() {
    if (scheme === "custom") applyToDocument()
  }

  async function saveCustom() {
    if (await patch({ user: { color_scheme: "custom", custom_colors: customColors } })) {
      savedCustomColors = { ...customColors }
      toast("notice", "Custom scheme saved.")
    } else {
      toast("alert", "Couldn't save the custom scheme.")
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
      onclick={() => choose({ scheme: candidate.key })}
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
  <button
    type="button"
    class="scheme-card"
    class:is-selected={scheme === "custom"}
    role="radio"
    aria-checked={scheme === "custom"}
    disabled={saving}
    onclick={() => choose({ scheme: "custom" })}
  >
    <span class="scheme-card-swatches" aria-hidden="true">
      {#each ["primary", "info", "warning"] as key (key)}
        <span class="scheme-card-swatch" style={`background: ${customColors[key]}`}></span>
      {/each}
    </span>
    <span class="scheme-card-label">Custom</span>
    <span class="scheme-card-description has-text-weak">Your own colors, checked against AA.</span>
  </button>
</div>

{#if scheme === "custom"}
  <div class="custom-scheme-editor">
    {#each CUSTOM_FIELDS as field (field.key)}
      <label class="custom-scheme-field">
        <input
          type="color"
          bind:value={customColors[field.key]}
          oninput={previewCustom}
          aria-label={`${field.label} color`}
        >
        <span>
          <span class="custom-scheme-field-label">{field.label}</span>
          {#if field.help}
            <span class="help">{field.help}</span>
          {/if}
        </span>
      </label>
    {/each}

    {#if warnings.length}
      <div class="notification is-warning custom-scheme-warnings" role="status">
        <p class="has-text-weight-semibold">Contrast check — these combinations fall below WCAG AA:</p>
        <ul>
          {#each warnings as warning (warning)}
            <li>{warning}</li>
          {/each}
        </ul>
        <p>You can still save — this is a heads-up, not a gate.</p>
      </div>
    {:else}
      <p class="help">All checked combinations meet WCAG AA in light and dark. ✓</p>
    {/if}

    <div class="buttons mt-3">
      <button type="button" class="button is-primary" disabled={saving || !customDirty} onclick={saveCustom}>
        Save custom scheme
      </button>
    </div>
  </div>
{/if}

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
        onclick={() => choose({ mode: candidate.key })}
      >
        {candidate.label}
      </button>
    {/each}
  </div>
  <p class="help">Auto follows your system's light/dark preference.</p>
</div>
