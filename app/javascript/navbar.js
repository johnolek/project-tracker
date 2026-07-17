// Bulma navbar burger toggle. Document-level delegation survives Turbo body
// swaps without any per-page lifecycle.
document.addEventListener("click", (event) => {
  const burger = event.target.closest(".navbar-burger")
  if (!burger) return

  const active = burger.classList.toggle("is-active")
  burger.setAttribute("aria-expanded", String(active))
  burger.closest(".navbar")?.querySelector(".navbar-menu")?.classList.toggle("is-active", active)
})
