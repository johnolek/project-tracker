// Svelte action for a <rhino-editor>: drop the caret into the editor as soon
// as it's ready, so opening an inline editor doesn't need a second click.
// tiptap's focus command alone doesn't move DOM focus while the view is still
// mounting, and the editor can rebuild its view right after mount (dropping
// focus set on the first view) — hence the direct DOM focus, the re-assert on
// every initialize, and the settle check.
export default function focusRhino(node) {
  const focus = () => {
    const dom = node.editor?.view?.dom
    if (!dom?.isConnected) {
      requestAnimationFrame(focus)
      return
    }
    dom.focus()
    node.editor.commands.focus("end")
  }
  const focusIfIdle = () => {
    if (!node.contains(document.activeElement)) focus()
  }

  node.addEventListener("rhino-initialize", focus)
  queueMicrotask(focus)
  const settle = setTimeout(focusIfIdle, 250)
  return {
    destroy() {
      node.removeEventListener("rhino-initialize", focus)
      clearTimeout(settle)
    },
  }
}
