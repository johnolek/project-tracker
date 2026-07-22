<script>
  // Embeddable feedback widget (PROJ-89), mounted inside the tracker's own
  // /embed/frame iframe on an allowlisted host page. Collapsed it is a small
  // "Feedback" tab; expanded it is a submission form. It measures itself and
  // posts pt-embed:size to the parent loader (which shows/resizes the iframe),
  // and reads pt-embed:context messages for the host page's URL/viewport.
  // Submits multipart, same-origin, to /embed/items — no CORS anywhere.
  let { submitUrl, origin, itemTypes = [] } = $props()

  // The server (frame) supplies the organization's configured types so a future
  // type appears here with no widget change; fall back to bug/idea only if the
  // prop is somehow empty. Default to "bug" when offered, else the first type.
  const types = itemTypes.length ? itemTypes : ["bug", "idea"]
  const defaultType = types.includes("bug") ? "bug" : types[0]
  const capitalize = (value) => value.charAt(0).toUpperCase() + value.slice(1)

  let root = $state(null)
  let expanded = $state(false)
  let title = $state("")
  let description = $state("")
  let itemType = $state(defaultType)

  let screenshot = $state(null)
  let screenshotUrl = $state(null)

  let submitting = $state(false)
  let error = $state("")
  let result = $state(null)

  let context = $state({ url: null, viewport: null })

  const canCapture = typeof navigator !== "undefined" &&
    !!navigator.mediaDevices && typeof navigator.mediaDevices.getDisplayMedia === "function"

  // The parent (loader) posts context targeted to this frame's origin; verify
  // the sender is the allowlisted host before trusting anything it says.
  function onMessage(event) {
    if (event.origin !== origin) return
    const data = event.data || {}
    if (data.type !== "pt-embed:context") return
    context = {
      url: typeof data.url === "string" ? data.url : null,
      viewport: data.viewport && typeof data.viewport.width === "number"
        ? `${data.viewport.width}x${data.viewport.height}`
        : null,
    }
  }

  function postSize() {
    if (!root || typeof window === "undefined") return
    const rect = root.getBoundingClientRect()
    window.parent.postMessage(
      { type: "pt-embed:size", width: Math.ceil(rect.width), height: Math.ceil(rect.height) },
      origin,
    )
  }

  // Report our size whenever the rendered box changes (expand/collapse, a
  // thumbnail or error appearing) so the iframe tracks the content exactly.
  $effect(() => {
    if (!root) return
    const observer = new ResizeObserver(() => postSize())
    observer.observe(root)
    postSize()

    window.addEventListener("message", onMessage)
    return () => {
      observer.disconnect()
      window.removeEventListener("message", onMessage)
    }
  })

  function expand() {
    expanded = true
  }

  function collapse() {
    expanded = false
  }

  // Ask the loader to dismiss the iframe for this page view. The loader keeps
  // its listeners and re-shows the widget on the next page view (turbo:load)
  // or a full reload — nothing is persisted here.
  function hide() {
    if (typeof window === "undefined") return
    window.parent.postMessage({ type: "pt-embed:hide" }, origin)
  }

  function setScreenshot(blob) {
    if (!blob) return
    if (screenshotUrl) URL.revokeObjectURL(screenshotUrl)
    screenshot = blob
    screenshotUrl = URL.createObjectURL(blob)
  }

  function clearScreenshot() {
    if (screenshotUrl) URL.revokeObjectURL(screenshotUrl)
    screenshot = null
    screenshotUrl = null
  }

  function onPaste(event) {
    const items = event.clipboardData && event.clipboardData.items
    if (!items) return
    for (const item of items) {
      if (item.type.startsWith("image/")) {
        const file = item.getAsFile()
        if (file) {
          setScreenshot(file)
          event.preventDefault()
        }
        return
      }
    }
  }

  function onFileChange(event) {
    const file = event.target.files && event.target.files[0]
    if (file) setScreenshot(file)
    event.target.value = ""
  }

  async function captureScreen() {
    let stream
    try {
      stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false })
    } catch {
      return
    }

    try {
      const track = stream.getVideoTracks()[0]
      const video = document.createElement("video")
      video.srcObject = stream
      await video.play()

      const canvas = document.createElement("canvas")
      canvas.width = video.videoWidth
      canvas.height = video.videoHeight
      canvas.getContext("2d").drawImage(video, 0, 0)

      const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/png"))
      if (blob) setScreenshot(new File([ blob ], "screenshot.png", { type: "image/png" }))
      track.stop()
    } finally {
      stream.getTracks().forEach((track) => track.stop())
    }
  }

  async function submit(event) {
    event.preventDefault()
    if (submitting) return
    error = ""

    if (!title.trim()) {
      error = "A title is required."
      return
    }

    submitting = true

    const form = new FormData()
    form.append("title", title.trim())
    form.append("description", description)
    form.append("item_type", itemType)
    form.append("origin", origin)
    if (context.url) form.append("page_url", context.url)
    if (context.viewport) form.append("viewport", context.viewport)
    form.append("user_agent", navigator.userAgent)
    if (screenshot) {
      form.append("screenshot", screenshot, screenshot.name || "screenshot.png")
    }

    const response = await fetch(submitUrl, { method: "POST", body: form }).catch(() => null)
    submitting = false

    if (!response || !response.ok) {
      const body = response ? await response.json().catch(() => null) : null
      error = body && body.errors ? body.errors.join(", ") : "Something went wrong. Please try again."
      return
    }

    result = await response.json()
  }

  function reset() {
    result = null
    error = ""
    title = ""
    description = ""
    itemType = defaultType
    clearScreenshot()
  }
</script>

<div class="feedback-widget" class:is-expanded={expanded} bind:this={root}>
  {#if !expanded}
    <!-- Rest: a tiny low-opacity nub hugging the corner. Hover or keyboard
         focus expands it into a pill exposing "Feedback" (opens the form) and
         a "×" (hides the widget until the next page view). -->
    <div class="feedback-collapsed">
      <button type="button" class="feedback-open" onclick={expand}>
        <span class="feedback-open-label">Feedback</span>
      </button>
      <button
        type="button"
        class="feedback-dismiss"
        aria-label="Hide feedback until next page"
        onclick={hide}
      >×</button>
    </div>
  {:else}
    <div class="feedback-panel">
      <header class="feedback-panel-head">
        <span class="feedback-panel-title">Send feedback</span>
        <button type="button" class="feedback-close" aria-label="Close" onclick={collapse}>×</button>
      </header>

      {#if result}
        <div class="feedback-success">
          <p class="feedback-success-line">
            Created
            <a href={result.url} target="_blank" rel="noopener">{result.key}</a>
          </p>
          <button type="button" class="button is-small is-primary" onclick={reset}>Submit another</button>
        </div>
      {:else}
        <form class="feedback-form" onsubmit={submit} onpaste={onPaste}>
          {#if error}
            <p class="feedback-error">{error}</p>
          {/if}

          <div class="feedback-field">
            <label class="feedback-label" for="feedback-title">Title</label>
            <input
              id="feedback-title"
              class="input is-small"
              type="text"
              bind:value={title}
              placeholder="Short summary"
              maxlength="200"
            />
          </div>

          <div class="feedback-field">
            <span class="feedback-label">Type</span>
            <div class="feedback-toggle" role="group" aria-label="Feedback type">
              {#each types as type (type)}
                <button
                  type="button"
                  class="feedback-toggle-option"
                  class:is-active={itemType === type}
                  aria-pressed={itemType === type}
                  onclick={() => (itemType = type)}
                >{capitalize(type)}</button>
              {/each}
            </div>
          </div>

          <div class="feedback-field">
            <label class="feedback-label" for="feedback-description">Details</label>
            <textarea
              id="feedback-description"
              class="textarea is-small"
              rows="3"
              bind:value={description}
              placeholder="What happened? Paste a screenshot here to attach it."
            ></textarea>
          </div>

          <div class="feedback-field">
            <span class="feedback-label">Screenshot</span>
            {#if screenshotUrl}
              <div class="feedback-thumb">
                <img src={screenshotUrl} alt="Attached screenshot" />
                <button type="button" class="feedback-thumb-remove" aria-label="Remove screenshot" onclick={clearScreenshot}>×</button>
              </div>
            {:else}
              <div class="feedback-shot-actions">
                <label class="button is-small feedback-attach">
                  Attach
                  <input type="file" accept="image/*" onchange={onFileChange} hidden />
                </label>
                {#if canCapture}
                  <button type="button" class="button is-small" onclick={captureScreen}>Capture screen</button>
                {/if}
              </div>
            {/if}
          </div>

          <div class="feedback-actions">
            <button type="submit" class="button is-small is-primary" disabled={submitting}>
              {submitting ? "Sending…" : "Submit"}
            </button>
          </div>
        </form>
      {/if}
    </div>
  {/if}
</div>
