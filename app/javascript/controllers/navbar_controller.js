import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "burger"]

  toggle() {
    const active = this.menuTarget.classList.toggle("is-active")
    this.burgerTarget.classList.toggle("is-active", active)
    this.burgerTarget.setAttribute("aria-expanded", active)
  }
}
