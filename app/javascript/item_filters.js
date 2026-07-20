// The board/prioritize item-filter predicate, extracted from Board.svelte so
// it is unit-testable (PROJ-79). Every criterion composes with AND. The server
// mirrors the type/points/tags core in ComparisonsController#matches_filters?;
// spec/fixtures/filter_cases.json drives both suites so the two sides can't
// drift silently.
//
// Bounds handling: unpointed items are excluded once a minimum is set (an item
// with no estimate can't be shown to clear a floor) but pass under any maximum
// (a ceiling shouldn't hide work simply because it lacks an estimate).
export default function matchesFilters(item, { query = "", reviewOnly = false, itemType = "", minPoints = null, maxPoints = null, tags = [], excludeTags = [] }) {
  const normalizedQuery = query.trim().toLowerCase()
  if (
    normalizedQuery &&
    !item.title.toLowerCase().includes(normalizedQuery) &&
    !item.key.toLowerCase().includes(normalizedQuery)
  ) return false
  if (reviewOnly && !item.needs_review) return false
  if (itemType && item.item_type !== itemType) return false
  if (minPoints != null && (item.points == null || item.points < minPoints)) return false
  if (maxPoints != null && item.points != null && item.points > maxPoints) return false
  if (tags.length && !tags.every((tag) => item.tags.includes(tag))) return false
  if (excludeTags.length && excludeTags.some((tag) => item.tags.includes(tag))) return false
  return true
}
