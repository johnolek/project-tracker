<script>
  // Small clipboard button, mounted next to the breadcrumb on the item page to
  // copy the item key. Uses the async clipboard API with a textarea execCommand
  // fallback for non-secure contexts.
  let { text, label = text } = $props()

  let copied = $state(false)
  let timer

  async function copy() {
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      const scratch = document.createElement("textarea")
      scratch.value = text
      scratch.style.position = "fixed"
      scratch.style.opacity = "0"
      document.body.appendChild(scratch)
      scratch.select()
      try { document.execCommand("copy") } catch { /* nothing else to try */ }
      document.body.removeChild(scratch)
    }
    copied = true
    clearTimeout(timer)
    timer = setTimeout(() => (copied = false), 1500)
  }
</script>

<button
  type="button"
  class="item-key-copy"
  class:is-copied={copied}
  title={`Copy ${label}`}
  aria-label={`Copy ${label} to clipboard`}
  onclick={copy}
>
  {#if copied}
    <span class="item-key-copied">Copied!</span>
  {:else}
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor"
         stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
    </svg>
  {/if}
</button>
