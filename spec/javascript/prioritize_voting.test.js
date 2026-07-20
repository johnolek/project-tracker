import { describe, it, expect, vi, beforeEach } from "vitest"
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte"
import { tick } from "svelte"
import Prioritize from "../../app/javascript/components/Prioritize.svelte"

// The optimistic-vote state machine (PROJ-64/PROJ-79): preloaded advance,
// failure rollback, and the single-slot vote queue. All server traffic is a
// mocked fetch; assertions are on what the user sees plus the POSTs sent.

function item(id, title) {
  return {
    id,
    key: `T-${id}`,
    title,
    notes_html: "",
    url: `/items/${id}`,
    move_url: `/items/${id}/move`,
    review_url: `/items/${id}/review`,
  }
}

const A = item(1, "Alpha")
const B = item(2, "Beta")
const C = item(3, "Gamma")
const D = item(4, "Delta")
const E = item(5, "Epsilon")
const F = item(6, "Zeta")

function baseProps(overrides = {}) {
  return {
    createUrl: "/comparisons",
    refreshUrl: "/selection",
    prioritiesUrl: "/priorities",
    pair: [A, B],
    next_pair: [C, D],
    count: 10,
    total: 20,
    remaining: 5,
    pinned_id: null,
    pinned_count: 0,
    reviewCount: 0,
    reviewUrl: "/review",
    itemTypes: [],
    allTags: [],
    statuses: [],
    doneStatusId: null,
    ...overrides,
  }
}

function jsonResponse(body) {
  return { ok: true, json: async () => body }
}

function deferred() {
  let resolve
  const promise = new Promise((r) => { resolve = r })
  return { promise, resolve }
}

beforeEach(() => {
  vi.restoreAllMocks()
})

describe("optimistic voting with a preloaded pair", () => {
  it("advances to the preloaded pair immediately and records in the background", async () => {
    const pending = deferred()
    global.fetch = vi.fn().mockReturnValue(pending.promise)

    render(Prioritize, { props: baseProps() })
    expect(screen.getByText("Alpha")).toBeTruthy()

    await fireEvent.click(screen.getByText("Alpha").closest(".comparison-card"))
    await tick()

    // Display advanced before the POST resolved.
    expect(screen.getByText("Gamma")).toBeTruthy()
    expect(screen.queryByText("Alpha")).toBeNull()

    const [url, options] = global.fetch.mock.calls[0]
    expect(url).toBe("/comparisons")
    const body = JSON.parse(options.body)
    expect(body.item_a_id).toBe(A.id)
    expect(body.item_b_id).toBe(B.id)
    expect(body.outcome).toBe("a_wins")
    expect(body.exclude_pair).toEqual([C.id, D.id])

    pending.resolve(jsonResponse({ pair: [E, F], count: 11, total: 20, remaining: 4, pinned_id: null }))
    await waitFor(() => expect(screen.getByText(/16 of 20 pairs compared/)).toBeTruthy())
    expect(screen.getByText(/4 to go/)).toBeTruthy()
  })

  it("rolls back the advance and restores the voted pair when the POST fails", async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: false, json: async () => ({}) })

    render(Prioritize, { props: baseProps() })
    await fireEvent.click(screen.getByText("Alpha").closest(".comparison-card"))

    await waitFor(() => expect(screen.getByText("Alpha")).toBeTruthy())
    expect(screen.queryByText("Gamma")).toBeNull()
    // Progress counts restored to the pre-vote snapshot.
    expect(screen.getByText(/15 of 20 pairs compared/)).toBeTruthy()
    expect(screen.getByText(/5 to go/)).toBeTruthy()
  })

  it("queues exactly one vote clicked mid-record and replays it after", async () => {
    const first = deferred()
    global.fetch = vi.fn()
      .mockReturnValueOnce(first.promise)
      .mockResolvedValue(jsonResponse({ pair: null, count: 12, total: 20, remaining: 3, pinned_id: null }))

    render(Prioritize, { props: baseProps() })

    await fireEvent.click(screen.getByText("Alpha").closest(".comparison-card"))
    await tick()
    // Now showing Gamma/Delta while the first vote records; two more clicks —
    // only ONE may queue.
    await fireEvent.click(screen.getByText("Gamma").closest(".comparison-card"))
    await fireEvent.click(screen.getByText("Delta").closest(".comparison-card"))
    expect(global.fetch).toHaveBeenCalledTimes(1)

    first.resolve(jsonResponse({ pair: [E, F], count: 11, total: 20, remaining: 4, pinned_id: null }))
    await waitFor(() => expect(global.fetch).toHaveBeenCalledTimes(2))

    const secondBody = JSON.parse(global.fetch.mock.calls[1][1].body)
    expect(secondBody.item_a_id).toBe(C.id)
    expect(secondBody.item_b_id).toBe(D.id)
    expect(secondBody.outcome).toBe("a_wins")
  })
})

describe("voting without a lookahead", () => {
  it("blocks until the server responds, then applies the fresh selection", async () => {
    global.fetch = vi.fn().mockResolvedValue(
      jsonResponse({ pair: [E, F], next_pair: null, count: 11, total: 20, remaining: 4, pinned_id: null })
    )

    render(Prioritize, { props: baseProps({ next_pair: null }) })
    await fireEvent.click(screen.getByText("Beta").closest(".comparison-card"))

    await waitFor(() => expect(screen.getByText("Epsilon")).toBeTruthy())
    const body = JSON.parse(global.fetch.mock.calls[0][1].body)
    expect(body.outcome).toBe("b_wins")
    expect(body.exclude_pair).toBeNull()
  })
})

describe("undo (PROJ-66)", () => {
  it("is disabled until a vote settles, then deletes the comparison and restores the voted pair", async () => {
    global.fetch = vi.fn().mockResolvedValue(
      jsonResponse({ pair: [E, F], count: 11, total: 20, remaining: 4, pinned_id: null, comparison_id: 77 })
    )

    render(Prioritize, { props: baseProps() })
    expect(screen.getByText("Undo").disabled).toBe(true)

    await fireEvent.click(screen.getByText("Alpha").closest(".comparison-card"))
    await waitFor(() => expect(screen.getByText("Undo").disabled).toBe(false))

    global.fetch.mockResolvedValue(
      jsonResponse({ pair: [E, F], count: 10, total: 20, remaining: 5, pinned_id: null })
    )
    await fireEvent.click(screen.getByText("Undo"))

    // DELETE hit the vote's comparison, excluding the undone pair from the refill.
    await waitFor(() => expect(global.fetch).toHaveBeenCalledTimes(2))
    const [url, options] = global.fetch.mock.calls[1]
    expect(url).toBe("/comparisons/77")
    expect(options.method).toBe("DELETE")
    expect(JSON.parse(options.body).exclude_pair).toEqual([A.id, B.id])

    // The undone pair is back on screen with the pre-vote progress, and the
    // undo has been consumed.
    await waitFor(() => expect(screen.getByText("Alpha")).toBeTruthy())
    expect(screen.getByText(/15 of 20 pairs compared/)).toBeTruthy()
    expect(screen.getByText("Undo").disabled).toBe(true)
  })

  it("restores the undo slot and complains when the DELETE fails", async () => {
    global.fetch = vi.fn().mockResolvedValue(
      jsonResponse({ pair: [E, F], count: 11, total: 20, remaining: 4, pinned_id: null, comparison_id: 78 })
    )

    render(Prioritize, { props: baseProps() })
    await fireEvent.click(screen.getByText("Alpha").closest(".comparison-card"))
    await waitFor(() => expect(screen.getByText("Undo").disabled).toBe(false))

    global.fetch.mockResolvedValue({ ok: false, json: async () => ({}) })
    await fireEvent.click(screen.getByText("Undo"))

    await waitFor(() => expect(screen.getByText("Undo").disabled).toBe(false))
  })

  it("invalidates undo on a context change", async () => {
    global.fetch = vi.fn().mockResolvedValue(
      jsonResponse({ pair: [E, F], next_pair: null, count: 11, total: 20, remaining: 4, pinned_id: null, comparison_id: 79 })
    )

    render(Prioritize, { props: baseProps() })
    await fireEvent.click(screen.getByText("Alpha").closest(".comparison-card"))
    await waitFor(() => expect(screen.getByText("Undo").disabled).toBe(false))

    await fireEvent.click(screen.getByText("Skip"))
    await waitFor(() => expect(screen.getByText("Undo").disabled).toBe(true))
  })
})
