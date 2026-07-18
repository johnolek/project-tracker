// Inline chip style for an item type, derived from the itemTypes prop the
// islands already receive ({ name, color, textColor }). ApplicationHelper#
// item_type_tag renders the same chip server-side for ERB; the color + readable
// foreground come from ItemType so both surfaces stay visually in step.
export default function itemTypeStyle(itemTypes, name) {
  const meta = itemTypes?.find((type) => type.name === name)
  return meta ? `background-color: ${meta.color}; color: ${meta.textColor}` : ""
}
