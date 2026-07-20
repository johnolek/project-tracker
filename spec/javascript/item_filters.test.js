import { describe, it, expect } from "vitest"
import matchesFilters from "../../app/javascript/item_filters"
import fixture from "../fixtures/filter_cases.json"

// The shared table pins the type/points/tags core against the Ruby mirror
// (ComparisonsController#matches_filters?); see filter_cases.json.
describe("matchesFilters (shared cases)", () => {
  for (const testCase of fixture.cases) {
    it(testCase.name, () => {
      const item = { title: "t", key: "K-1", needs_review: false, ...testCase.item }
      const filters = {
        itemType: testCase.filters.item_type ?? "",
        minPoints: testCase.filters.min_points ?? null,
        maxPoints: testCase.filters.max_points ?? null,
        tags: testCase.filters.tags ?? [],
        excludeTags: testCase.filters.exclude_tags ?? [],
      }
      expect(matchesFilters(item, filters)).toBe(testCase.expected)
    })
  }
})

describe("matchesFilters (board-only criteria)", () => {
  const item = { title: "Fix login crash", key: "TRAC-12", item_type: "bug", points: 1, tags: [], needs_review: false }

  it("matches the query against title or key, case-insensitively", () => {
    expect(matchesFilters(item, { query: "LOGIN" })).toBe(true)
    expect(matchesFilters(item, { query: "trac-12" })).toBe(true)
    expect(matchesFilters(item, { query: "nowhere" })).toBe(false)
  })

  it("reviewOnly keeps only flagged items", () => {
    expect(matchesFilters(item, { reviewOnly: true })).toBe(false)
    expect(matchesFilters({ ...item, needs_review: true }, { reviewOnly: true })).toBe(true)
  })
})
