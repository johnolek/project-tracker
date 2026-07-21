import { describe, it, expect, vi } from "vitest"
import { render, screen, fireEvent, waitFor } from "@testing-library/svelte"
import ItemSidebar from "../../app/javascript/components/ItemSidebar.svelte"

// The one-tap points row (PROJ-87): tap sets, tapping the active value clears.

function baseItem(overrides = {}) {
  return {
    id: 1,
    status_id: 10,
    item_type: "feature",
    points: null,
    parent_id: null,
    tags: [],
    strength: 0,
    provenance: "user_created",
    ai_reviewed_at: null,
    created_at: 1_700_000_000,
    updated_at: 1_700_000_000,
    ...overrides,
  }
}

function renderSidebar(item) {
  return render(ItemSidebar, {
    props: {
      item,
      updateUrl: "/items/1",
      statuses: [{ id: 10, name: "New" }],
      itemTypes: [{ name: "feature" }],
      pointOptions: [1, 2, 3, 5, 8, 13],
      allTags: [],
      parentOptions: [],
    },
  })
}

function pointsGroup() {
  return screen.getByRole("radiogroup", { name: "Points estimate" })
}

describe("points as one-tap buttons", () => {
  it("offers every option as a button and PATCHes a tap", async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: true, json: async () => baseItem({ points: 5 }) })
    renderSidebar(baseItem())

    const buttons = [...pointsGroup().querySelectorAll("button")]
    expect(buttons.map((button) => button.textContent.trim())).toEqual(["1", "2", "3", "5", "8", "13"])

    await fireEvent.click(buttons[3])
    await waitFor(() => expect(global.fetch).toHaveBeenCalledOnce())
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ item: { points: 5 } })
    await waitFor(() => expect(buttons[3].getAttribute("aria-checked")).toBe("true"))
  })

  it("clears the estimate when the active value is tapped again", async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: true, json: async () => baseItem({ points: null }) })
    renderSidebar(baseItem({ points: 5 }))

    const active = [...pointsGroup().querySelectorAll("button")].find((button) => button.textContent.trim() === "5")
    expect(active.getAttribute("aria-checked")).toBe("true")

    await fireEvent.click(active)
    await waitFor(() => expect(global.fetch).toHaveBeenCalledOnce())
    expect(JSON.parse(global.fetch.mock.calls[0][1].body)).toEqual({ item: { points: null } })
    await waitFor(() => expect(active.getAttribute("aria-checked")).toBe("false"))
  })

  it("renders a legacy non-fibonacci value as its own segment, in order", () => {
    global.fetch = vi.fn()
    renderSidebar(baseItem({ points: 4 }))

    const labels = [...pointsGroup().querySelectorAll("button")].map((button) => button.textContent.trim())
    expect(labels).toEqual(["1", "2", "3", "4", "5", "8", "13"])
  })
})
