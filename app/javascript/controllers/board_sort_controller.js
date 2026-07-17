import { Controller } from "@hotwired/stimulus"

// Sorts cards within each board column by strength, created date, or points.
// Sorting lives in the DOM (not a query param) because Turbo Stream re-renders
// always arrive in the server's default order; a MutationObserver re-applies
// the active sort after each re-render. Paused while a drag is in flight (the
// board controller dispatches board:dragStart/dragEnd) so reordering never
// fights SortableJS. The choice persists per board in localStorage.
export default class extends Controller {
  static targets = ["button"]
  static values = { storageKey: String }

  static defaultDirections = { strength: "desc", created: "desc", points: "asc" }

  connect() {
    const { key, dir } = this.read()
    this.key = key
    this.dir = dir
    this.paused = false
    this.observer = new MutationObserver(() => this.apply())
    this.observe()
    this.apply()
    this.renderButtons()
  }

  disconnect() {
    this.observer.disconnect()
  }

  choose(event) {
    const key = event.params.key
    this.dir = key === this.key ? (this.dir === "asc" ? "desc" : "asc")
                                : this.constructor.defaultDirections[key]
    this.key = key
    this.save()
    this.apply()
    this.renderButtons()
  }

  pause() {
    this.paused = true
  }

  resume() {
    this.paused = false
    this.apply()
  }

  apply() {
    if (this.paused) return

    this.observer.disconnect()
    this.element.querySelectorAll("ul.status-cards").forEach((list) => {
      Array.from(list.querySelectorAll(".board-card"))
        .map((card, index) => [card, this.sortValue(card), index])
        .sort((a, b) => (a[1] - b[1]) || (a[2] - b[2]))
        .forEach(([card]) => list.appendChild(card))
    })
    this.observe()
  }

  // Missing values (e.g. unpointed items) sort last regardless of direction.
  sortValue(card) {
    const raw = card.dataset[this.key]
    if (raw === undefined || raw === "") return Number.MAX_VALUE

    const value = parseFloat(raw)
    return this.dir === "asc" ? value : -value
  }

  renderButtons() {
    this.buttonTargets.forEach((button) => {
      const active = button.dataset.boardSortKeyParam === this.key
      button.classList.toggle("is-primary", active)
      button.setAttribute("aria-pressed", active)
      button.textContent = button.dataset.label + (active ? (this.dir === "asc" ? " ↑" : " ↓") : "")
    })
  }

  observe() {
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  save() {
    localStorage.setItem(this.storageKeyValue, JSON.stringify({ key: this.key, dir: this.dir }))
  }

  read() {
    try {
      const saved = JSON.parse(localStorage.getItem(this.storageKeyValue))
      if (saved && this.constructor.defaultDirections[saved.key]) return saved
    } catch {
      // fall through to the default
    }
    return { key: "created", dir: "desc" }
  }
}
