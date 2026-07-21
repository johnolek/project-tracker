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
  // Sticky toasts (PROJ-67's "Add another") opt out entirely — they stay until
  // dismissed by the close button or a swipe.
  function autodismiss(node, toast) {
    if (toast.sticky) return

    const id = toast.id
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

  // Touch/pen swipe-to-dismiss (PROJ-81): the toast tracks a horizontal drag
  // and fades as it travels; releasing past a third of its width dismisses,
  // anything less springs back. Mouse users keep the close button — a mouse
  // drag stays available for selecting the toast's text.
  function swipeDismiss(node, id) {
    let pointerId = null
    let startX = 0

    function down(event) {
      if (event.pointerType === "mouse" || pointerId !== null) return
      pointerId = event.pointerId
      startX = event.clientX
      node.setPointerCapture(pointerId)
    }

    function move(event) {
      if (event.pointerId !== pointerId) return
      const dx = event.clientX - startX
      node.style.transform = `translateX(${dx}px)`
      node.style.opacity = String(Math.max(0.15, 1 - Math.abs(dx) / node.offsetWidth))
    }

    function settle(event, cancelled) {
      if (event.pointerId !== pointerId) return
      pointerId = null
      const dx = event.clientX - startX
      if (!cancelled && Math.abs(dx) > node.offsetWidth / 3) {
        dismiss(id)
      } else {
        node.style.transform = ""
        node.style.opacity = ""
      }
    }

    const up = (event) => settle(event, false)
    const cancel = (event) => settle(event, true)

    node.addEventListener("pointerdown", down)
    node.addEventListener("pointermove", move)
    node.addEventListener("pointerup", up)
    node.addEventListener("pointercancel", cancel)

    return {
      destroy() {
        node.removeEventListener("pointerdown", down)
        node.removeEventListener("pointermove", move)
        node.removeEventListener("pointerup", up)
        node.removeEventListener("pointercancel", cancel)
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
      use:autodismiss={toast}
      use:swipeDismiss={toast.id}
    >
      <button class="delete" aria-label="Dismiss notification" onclick={() => dismiss(toast.id)}></button>
      {toast.message}
      {#if toast.action}
        <!-- action.method (e.g. "post" for Add another's draft creation) rides
             through Turbo's data-turbo-method; absent means a plain GET link. -->
        <a class="toast-action" href={toast.action.href} data-turbo-method={toast.action.method}>{toast.action.label}</a>
      {/if}
    </div>
  {/each}
</div>
