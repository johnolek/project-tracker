// Standalone bundle for the embedded feedback frame (PROJ-89). The frame loads
// only this — not the full application.js (Turbo, ActionCable, every island) —
// so the widget stays lightweight in a third-party context. Mounts the single
// FeedbackWidget island the frame view renders.
import { mount } from "svelte"
import FeedbackWidget from "./components/FeedbackWidget.svelte"

function mountWidget() {
  const el = document.querySelector("[data-svelte-component='FeedbackWidget']")
  if (!el) return
  const props = el.dataset.props ? JSON.parse(el.dataset.props) : {}
  mount(FeedbackWidget, { target: el, props })
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mountWidget)
} else {
  mountWidget()
}
