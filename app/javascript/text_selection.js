// A select-drag that ends on a click-to-edit block fires a click; opening the
// editor then would eat the selection the user just made to copy text
// (PROJ-82). Callers skip the edit transition while any selection is live —
// a plain click collapses the selection on mousedown, so this only blocks
// clicks that themselves selected text (including double-click word-selects).
export default function hasTextSelection() {
  const selection = window.getSelection()
  return Boolean(selection && !selection.isCollapsed)
}
