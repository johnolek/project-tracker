// Bulma navbar interactions via document-level click delegation. Delegating on
// the document (rather than binding per element) survives Turbo body swaps
// without any per-page lifecycle.

const closeDropdowns = (except) => {
  document.querySelectorAll(".navbar-item.has-dropdown.is-active").forEach((dropdown) => {
    if (dropdown === except) return
    dropdown.classList.remove("is-active")
    dropdown.querySelector(".navbar-link")?.setAttribute("aria-expanded", "false")
  })
}

document.addEventListener("click", (event) => {
  const burger = event.target.closest(".navbar-burger")
  if (burger) {
    const active = burger.classList.toggle("is-active")
    burger.setAttribute("aria-expanded", String(active))
    burger.closest(".navbar")?.querySelector(".navbar-menu")?.classList.toggle("is-active", active)
    return
  }

  // Dropdown trigger. On desktop `is-hoverable` opens the menu on hover/focus;
  // this explicit toggle is what makes it work on touch, where those never fire.
  const trigger = event.target.closest(".navbar-link")
  const dropdown = trigger?.closest(".navbar-item.has-dropdown")
  if (dropdown) {
    event.preventDefault()
    const active = dropdown.classList.toggle("is-active")
    trigger.setAttribute("aria-expanded", String(active))
    closeDropdowns(dropdown)
    return
  }

  // A click anywhere else (including a dropdown item) dismisses open dropdowns.
  closeDropdowns()
})
