import { describe, it, expect, vi, beforeEach } from "vitest"
import { render, screen, fireEvent } from "@testing-library/svelte"
import { tick } from "svelte"
import FeedbackWidget from "../../app/javascript/components/FeedbackWidget.svelte"

// PROJ-89 embeddable widget: the collapsed pill's "×" posts a pt-embed:hide
// message to the parent loader (targeted to the host origin) to dismiss the
// widget for the current page view, and the frame trusts parent context only
// from that same origin.

const HOST = "https://host.example"

// The widget observes its own box with ResizeObserver, which jsdom lacks.
class NoopResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
}

beforeEach(() => {
  vi.restoreAllMocks()
  global.ResizeObserver = NoopResizeObserver
})

function renderWidget(itemTypes) {
  return render(FeedbackWidget, {
    props: { submitUrl: "/embed/items", origin: HOST, itemTypes },
  })
}

describe("dismiss for the current page view", () => {
  it("posts pt-embed:hide to the host origin from the collapsed pill, with no persistence", async () => {
    const post = vi.spyOn(window.parent, "postMessage").mockImplementation(() => {})

    renderWidget()
    await tick()

    // The dismiss control lives on the collapsed pill, not the expanded panel.
    const hide = screen.getByLabelText("Hide feedback until next page")
    expect(hide.textContent.trim()).toBe("×")

    await fireEvent.click(hide)

    const hideCall = post.mock.calls.find(([msg]) => msg && msg.type === "pt-embed:hide")
    expect(hideCall).toBeTruthy()
    expect(hideCall[1]).toBe(HOST)
    // No client-side persistence of the hidden state.
    expect(window.localStorage.length).toBe(0)
    expect(window.sessionStorage.length).toBe(0)
  })
})

describe("item type pills (PROJ-106)", () => {
  async function expand(itemTypes) {
    renderWidget(itemTypes)
    await tick()
    await fireEvent.click(screen.getByText("Feedback"))
    await tick()
  }

  it("renders one capitalized pill per server-supplied type, defaulting to bug", async () => {
    await expand(["bug", "feature", "idea"])

    for (const label of ["Bug", "Feature", "Idea"]) {
      expect(screen.getByRole("button", { name: label })).toBeTruthy()
    }
    expect(screen.getByRole("button", { name: "Bug" }).getAttribute("aria-pressed")).toBe("true")
    expect(screen.getByRole("button", { name: "Feature" }).getAttribute("aria-pressed")).toBe("false")
  })

  it("defaults to the first type when bug is not offered", async () => {
    await expand(["chore", "idea"])

    expect(screen.getByRole("button", { name: "Chore" }).getAttribute("aria-pressed")).toBe("true")
  })

  it("submits the selected type", async () => {
    await expand(["bug", "feature", "idea"])
    await fireEvent.input(screen.getByLabelText("Title"), { target: { value: "A feature" } })
    await fireEvent.click(screen.getByRole("button", { name: "Feature" }))

    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ key: "X-1", url: "/x" }) })
    global.fetch = fetchMock

    await fireEvent.submit(screen.getByText("Submit").closest("form"))

    expect(fetchMock.mock.calls[0][1].body.get("item_type")).toBe("feature")
  })
})

describe("context origin guard", () => {
  it("ignores pt-embed:context from a foreign origin and trusts the host origin", async () => {
    renderWidget()

    window.dispatchEvent(
      new MessageEvent("message", {
        origin: "https://evil.example",
        data: { type: "pt-embed:context", url: "https://evil.example/x", viewport: { width: 9, height: 9 } },
      }),
    )
    await tick()

    window.dispatchEvent(
      new MessageEvent("message", {
        origin: HOST,
        data: { type: "pt-embed:context", url: "https://host.example/page", viewport: { width: 800, height: 600 } },
      }),
    )
    await tick()

    // Expand and submit so the recorded context lands in the POST body.
    await fireEvent.click(screen.getByText("Feedback"))
    await tick()
    await fireEvent.input(screen.getByLabelText("Title"), { target: { value: "A bug" } })

    const fetchMock = vi.fn().mockResolvedValue({ ok: true, json: async () => ({ key: "X-1", url: "/x" }) })
    global.fetch = fetchMock

    await fireEvent.submit(screen.getByText("Submit").closest("form"))

    const body = fetchMock.mock.calls[0][1].body
    expect(body.get("page_url")).toBe("https://host.example/page")
    expect(body.get("viewport")).toBe("800x600")
  })
})
