// Svelte islands over server-rendered pages: any element with
// data-svelte-component mounts the named component with data-props as its
// props. Mounted on every Turbo visit; unmounted before Turbo caches the page
// so restored snapshots hold an empty root and remount cleanly.
import { mount, unmount } from "svelte"
import Board from "./components/Board.svelte"
import ItemEditor from "./components/ItemEditor.svelte"
import ItemLinkField from "./components/ItemLinkField.svelte"
import ItemSidebar from "./components/ItemSidebar.svelte"
import Prioritize from "./components/Prioritize.svelte"
import Toasts from "./components/Toasts.svelte"

const registry = { Board, ItemEditor, ItemLinkField, ItemSidebar, Prioritize, Toasts }
const active = new Map()

function mountIslands() {
  for (const el of document.querySelectorAll("[data-svelte-component]")) {
    if (active.has(el)) continue
    const Component = registry[el.dataset.svelteComponent]
    if (!Component) continue
    const props = el.dataset.props ? JSON.parse(el.dataset.props) : {}
    active.set(el, mount(Component, { target: el, props }))
  }
}

function unmountIslands() {
  for (const instance of active.values()) unmount(instance)
  active.clear()
}

document.addEventListener("turbo:load", mountIslands)
document.addEventListener("turbo:before-cache", unmountIslands)
