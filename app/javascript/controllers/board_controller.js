import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Drag cards between status columns. Each column's <ul> is a Sortable in a
// shared group; dropping into a different column PATCHes the item's status.
//
// Turbo echo: Item#broadcast_board re-renders this whole board over the Turbo
// Stream after every update, including the successful move's own echo. A replace
// arriving mid-drag would rip the dragged node out of the DOM, so while a drag is
// in flight we intercept turbo:before-stream-render and hold the replacement.
// After the drop the board is left in its optimistic state; the post-drop echo
// (server state now matches) is allowed through and reconciles everything.
export default class extends Controller {
  static targets = ["list"]

  connect() {
    this.dragging = false
    this.deferredRender = null
    this.sortables = this.listTargets.map((list) =>
      Sortable.create(list, {
        group: "board",
        animation: 150,
        draggable: ".board-card",
        onStart: () => { this.dragging = true },
        onEnd: (event) => this.onEnd(event)
      })
    )
  }

  disconnect() {
    this.sortables?.forEach((sortable) => sortable.destroy())
    this.sortables = []
  }

  onEnd(event) {
    this.dragging = false

    if (event.to.dataset.statusId === event.from.dataset.statusId) {
      this.flushDeferredRender()
      return
    }

    this.move(event).catch((error) => {
      console.error(error)
      this.revert(event)
    })
  }

  async move(event) {
    const response = await fetch(event.item.dataset.moveUrl, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ status_id: event.to.dataset.statusId })
    })

    if (!response.ok) {
      throw new Error(`Move failed with status ${response.status}`)
    }

    // A stale pre-move render captured mid-drag would revert the card; discard
    // it and let the authoritative post-move echo render normally.
    this.deferredRender = null
  }

  revert(event) {
    const reference = event.from.children[event.oldIndex] || null
    event.from.insertBefore(event.item, reference)
  }

  beforeStreamRender(event) {
    if (event.target.getAttribute("target") !== this.element.id) return
    if (!this.dragging) return

    const render = event.detail.render
    event.detail.render = (streamElement) => {
      this.deferredRender = () => render(streamElement)
    }
  }

  flushDeferredRender() {
    if (!this.deferredRender) return

    const render = this.deferredRender
    this.deferredRender = null
    render()
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
