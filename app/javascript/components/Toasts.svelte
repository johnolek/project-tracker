<script>
  import { fly, fade } from "svelte/transition"
  import { flip } from "svelte/animate"

  let { toasts: initial = [] } = $props()

  const DURATION = 5000
  const COLORS = { notice: "is-success", alert: "is-danger" }
  const reduceMotion =
    typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches

  let nextId = 0
  // svelte-ignore state_referenced_locally -- islands remount per visit; props seed state once
  let toasts = $state(initial.map((toast) => ({ ...toast, id: nextId++ })))

  function add(toast) {
    toasts.push({ ...toast, id: nextId++ })
  }

  function dismiss(id) {
    const index = toasts.findIndex((toast) => toast.id === id)
    if (index !== -1) toasts.splice(index, 1)
  }

  function colorClass(type) {
    return COLORS[type] ?? "is-info"
  }

  // Each toast auto-dismisses after DURATION; the timer pauses while the toast
  // is hovered or focused so it can be read (and its close button reached).
  function autodismiss(node, id) {
    let remaining = DURATION
    let startedAt
    let timer

    function start() {
      startedAt = Date.now()
      timer = setTimeout(() => dismiss(id), remaining)
    }

    function pause() {
      clearTimeout(timer)
      remaining -= Date.now() - startedAt
    }

    node.addEventListener("mouseenter", pause)
    node.addEventListener("mouseleave", start)
    node.addEventListener("focusin", pause)
    node.addEventListener("focusout", start)
    start()

    return {
      destroy() {
        clearTimeout(timer)
        node.removeEventListener("mouseenter", pause)
        node.removeEventListener("mouseleave", start)
        node.removeEventListener("focusin", pause)
        node.removeEventListener("focusout", start)
      },
    }
  }

  // Other islands can raise a toast client-side by dispatching on document:
  // document.dispatchEvent(new CustomEvent("toast", { detail: { type, message } }))
  $effect(() => {
    const handler = (event) => add(event.detail)
    document.addEventListener("toast", handler)
    return () => document.removeEventListener("toast", handler)
  })

  // Reduced motion keeps the opacity fade but drops the vertical slide (y: 0).
  const flyIn = reduceMotion ? { y: 0, duration: 200 } : { y: -16, duration: 250 }
  const flipDuration = reduceMotion ? 0 : 200
</script>

<div class="toast-stack">
  {#each toasts as toast (toast.id)}
    <div
      class="notification toast {colorClass(toast.type)}"
      role="status"
      aria-live="polite"
      in:fly={flyIn}
      out:fade={{ duration: 200 }}
      animate:flip={{ duration: flipDuration }}
      use:autodismiss={toast.id}
    >
      <button class="delete" aria-label="Dismiss notification" onclick={() => dismiss(toast.id)}></button>
      {toast.message}
    </div>
  {/each}
</div>
