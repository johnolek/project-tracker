import "@hotwired/turbo-rails"
import "./navbar"
import "./islands"
import "./passkey"
import "rhino-editor"

// Register the no-op service worker so the app is installable as a PWA.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
  })
}
