import { describe, it, expect, vi, beforeEach } from "vitest"
import { render, screen, waitFor } from "@testing-library/svelte"
import Board from "../../app/javascript/components/Board.svelte"

// Board's cable/drag reconciliation (PROJ-79): live upsert/remove/strengths
// messages apply to the card list, and messages arriving MID-DRAG are buffered
// until the drop settles instead of yanking the DOM out from under SortableJS.

const hoisted = vi.hoisted(() => ({ cable: {}, sortable: {} }))

vi.mock("../../app/javascript/cable", () => ({
  default: {
    subscriptions: {
      create: (_params, handlers) => {
        hoisted.cable.received = handlers.received
        return { unsubscribe() {} }
      },
    },
  },
}))

vi.mock("sortablejs", () => ({
  default: {
    create: (_el, options) => {
      hoisted.sortable.options = options
      return { destroy() {} }
    },
  },
}))

function item(id, overrides = {}) {
  return {
    id,
    key: `T-${id}`,
    title: `Item ${id}`,
    item_type: "feature",
    points: null,
    strength: 0,
    status_id: 1,
    tags: [],
    needs_review: false,
    review_note: null,
    url: `/items/${id}`,
    move_url: `/items/${id}/move`,
    created_at: id,
    ...overrides,
  }
}

function renderBoard(items) {
  return render(Board, {
    props: {
      projectId: 7,
      storageKey: "board-test",
      statuses: [
        { id: 1, name: "New", category: "open", position: 1 },
        { id: 2, name: "Done", category: "done", position: 2 },
      ],
      itemTypes: [{ name: "feature", color: "#888888" }],
      items,
    },
  })
}

beforeEach(() => {
  localStorage.clear()
  hoisted.cable.received = null
  hoisted.sortable.options = null
})

describe("cable messages", () => {
  it("upsert adds a new card and updates an existing one", async () => {
    renderBoard([item(1)])
    expect(screen.getByText("Item 1")).toBeTruthy()

    hoisted.cable.received({ action: "upsert", item: item(2) })
    await waitFor(() => expect(screen.getByText("Item 2")).toBeTruthy())

    hoisted.cable.received({ action: "upsert", item: item(1, { title: "Renamed 1" }) })
    await waitFor(() => expect(screen.getByText("Renamed 1")).toBeTruthy())
    expect(screen.queryByText("Item 1")).toBeNull()
  })

  it("remove deletes the card", async () => {
    renderBoard([item(1), item(2)])

    hoisted.cable.received({ action: "remove", id: 1 })
    await waitFor(() => expect(screen.queryByText("Item 1")).toBeNull())
    expect(screen.getByText("Item 2")).toBeTruthy()
  })

  it("strengths updates only the listed items", async () => {
    const { container } = renderBoard([
      item(1, { strength: 0 }),
      item(2, { strength: 0 }),
    ])

    hoisted.cable.received({ action: "strengths", strengths: { 1: 2.5 } })
    await waitFor(() => expect(container.textContent).toContain("+2.5"))
  })
})

describe("messages during a drag", () => {
  it("buffers cable messages while dragging and applies them after the drop", async () => {
    renderBoard([item(1)])
    const options = hoisted.sortable.options
    expect(options).toBeTruthy()

    options.onStart()
    hoisted.cable.received({ action: "upsert", item: item(3) })

    // Mid-drag: the message must NOT have applied.
    await new Promise((resolve) => setTimeout(resolve, 20))
    expect(screen.queryByText("Item 3")).toBeNull()

    // Same-position drop: no DOM surgery, buffered messages then drain.
    const el = document.createElement("li")
    el.dataset.itemId = "1"
    const list = document.querySelector("[data-status-id='1']")
    options.onEnd({ item: el, to: list, from: list, oldIndex: 0, newIndex: 0 })

    await waitFor(() => expect(screen.getByText("Item 3")).toBeTruthy())
  })
})
