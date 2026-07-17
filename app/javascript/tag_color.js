// Deterministic tag color class from a tag name. djb2 hash (seed 5381, times 33)
// over the lowercased UTF-8 bytes, masked to 32 bits, mod eight color buckets.
// Must stay byte-for-byte identical to ApplicationHelper#tag_color_class so a
// tag gets the same .tag-color-N in ERB and on the Svelte board.
export default function tagColorClass(name) {
  const bytes = new TextEncoder().encode(String(name).toLowerCase())
  let hash = 5381
  for (const byte of bytes) hash = (hash * 33 + byte) >>> 0
  return `tag-color-${hash % 8}`
}
