import { Controller } from "@hotwired/stimulus"

// Live title filter for the board. The input lives outside the board partial so
// Turbo Stream full-board re-renders never clobber it; a MutationObserver
// re-applies the active filter whenever a re-render swaps the cards out.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.observer = new MutationObserver(() => this.apply())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer.disconnect()
  }

  filter() {
    this.apply()
  }

  apply() {
    const query = this.inputTarget.value.trim().toLowerCase()
    this.element.querySelectorAll(".board-card").forEach((card) => {
      const title = card.querySelector(".board-card-title")?.textContent.toLowerCase() ?? ""
      card.hidden = query !== "" && !title.includes(query)
    })
  }
}
