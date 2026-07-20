# PROJ-77 follow-up: type names are lowercase by fiat (models enforce it on
# write from here on); fold any existing mixed-case rows. The item_types
# unique index is on lower(name), so lowering can't introduce conflicts.
class LowercaseItemTypes < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE item_types SET name = LOWER(name) WHERE name <> LOWER(name)"
    execute "UPDATE items SET item_type = LOWER(item_type) WHERE item_type <> LOWER(item_type)"
  end

  def down; end
end
