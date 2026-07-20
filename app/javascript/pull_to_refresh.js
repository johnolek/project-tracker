// Pull-to-refresh for the installed PWA (PROJ-71). In standalone display mode
// there is no browser chrome, so a stale page has no reload affordance; the
// service worker is a network passthrough, so a reload always fetches fresh.
// Only touch gestures that start with the page scrolled to the very top count,
// and only when no ancestor scroll container is itself scrolled down.

const THRESHOLD_PX = 70
const DAMPING = 0.4
const MAX_PULL_PX = 110

const standalone =
  window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true

let indicator = null
let startY = null
let pulling = false
let reloading = false

function ensureIndicator() {
  if (indicator && indicator.isConnected) return indicator

  indicator = document.createElement("div")
  indicator.className = "pull-refresh-indicator"
  indicator.innerHTML = '<span class="pull-refresh-arrow" aria-hidden="true">↓</span>'
  document.body.appendChild(indicator)
  return indicator
}

function ancestorScrolledDown(node) {
  for (let el = node instanceof Element ? node : node.parentElement; el; el = el.parentElement) {
    if (el.scrollTop > 0) return true
  }
  return false
}

function pullDistance(touchY) {
  return Math.min((touchY - startY) * DAMPING, MAX_PULL_PX)
}

function onTouchStart(event) {
  if (reloading || event.touches.length !== 1) return
  if (document.scrollingElement.scrollTop > 0) return
  if (ancestorScrolledDown(event.target)) return

  startY = event.touches[0].clientY
  pulling = false
}

function onTouchMove(event) {
  if (reloading || startY === null || event.touches.length !== 1) return

  const distance = pullDistance(event.touches[0].clientY)
  if (distance <= 0) {
    if (pulling) settle()
    return
  }

  pulling = true
  const el = ensureIndicator()
  el.classList.add("is-pulling")
  el.classList.toggle("is-armed", distance >= THRESHOLD_PX)
  el.style.transform = `translate(-50%, ${distance}px)`
}

function onTouchEnd(event) {
  if (reloading || startY === null) return

  const armed = pulling && pullDistance(event.changedTouches[0].clientY) >= THRESHOLD_PX
  startY = null

  if (!pulling) return
  if (!armed) {
    settle()
    return
  }

  reloading = true
  const el = ensureIndicator()
  el.classList.add("is-reloading")
  el.querySelector(".pull-refresh-arrow").textContent = ""
  window.location.reload()
}

function settle() {
  pulling = false
  if (!indicator || !indicator.isConnected) return

  indicator.classList.remove("is-pulling", "is-armed")
  indicator.style.transform = ""
}

if (standalone) {
  document.addEventListener("touchstart", onTouchStart, { passive: true })
  document.addEventListener("touchmove", onTouchMove, { passive: true })
  document.addEventListener("touchend", onTouchEnd, { passive: true })
  document.addEventListener("touchcancel", settle, { passive: true })
}
