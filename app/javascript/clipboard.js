// Click-to-copy via document-level delegation (survives Turbo body swaps).
// Any element with data-clipboard-text copies that value on click; the result
// is announced through the Toasts island's document "toast" event.
document.addEventListener("click", async (event) => {
  const trigger = event.target.closest("[data-clipboard-text]")
  if (!trigger) return

  const toast = (type, message) =>
    document.dispatchEvent(new CustomEvent("toast", { detail: { type, message } }))

  try {
    await navigator.clipboard.writeText(trigger.dataset.clipboardText)
    toast("notice", trigger.dataset.clipboardMessage ?? "Copied to clipboard.")
  } catch {
    toast("alert", "Copy failed — select the text and copy it manually.")
  }
})
