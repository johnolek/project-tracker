import "@hotwired/turbo-rails"
import "./navbar"
import "./clipboard"
import "./islands"
import "./passkey"
import "./pull_to_refresh"
import "rhino-editor"

// Register the no-op service worker so the app is installable as a PWA.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker.js", { scope: "/" })
  })
}
