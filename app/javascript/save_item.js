// Shared PATCH for the item-detail islands: saves attrs and returns the fresh
// detail payload, or null after announcing the failure through the toast stack.
export default async function saveItem(updateUrl, attrs) {
  const response = await fetch(updateUrl, {
    method: "PATCH",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
    },
    body: JSON.stringify({ item: attrs }),
  }).catch(() => null)

  if (response?.ok) return response.json()

  const errors = response ? (await response.json().catch(() => null))?.errors : null
  document.dispatchEvent(
    new CustomEvent("toast", {
      detail: { type: "alert", message: errors?.join(", ") ?? "Couldn't save — check your connection." },
    })
  )
  return null
}
