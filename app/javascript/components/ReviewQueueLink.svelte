<script>
  // "Review queue" link with a live count badge. Mounted on the board (static)
  // and the prioritize view, where flagging an item fires a document
  // "review:flagged" event so the badge bumps without a reload (PROJ-65).
  let { url, count: initialCount } = $props()

  // svelte-ignore state_referenced_locally -- islands remount per visit; prop seeds state once
  let count = $state(initialCount ?? 0)

  $effect(() => {
    const bump = () => { count += 1 }
    document.addEventListener("review:flagged", bump)
    return () => document.removeEventListener("review:flagged", bump)
  })
</script>

<a class="button" href={url}>
  Review queue
  {#if count > 0}<span class="tag is-warning ml-2">{count}</span>{/if}
</a>
