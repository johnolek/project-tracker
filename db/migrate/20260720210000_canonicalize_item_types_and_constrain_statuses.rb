# PROJ-77: items.item_type is denormalized; canonicalize any rows whose casing
# drifted from the configured type (they escaped the rename cascade and delete
# guard), and back the new status name-uniqueness validation with a functional
# unique index so name-addressed API calls stay deterministic.
class CanonicalizeItemTypesAndConstrainStatuses < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE items
      SET item_type = item_types.name
      FROM projects, item_types
      WHERE items.project_id = projects.id
        AND item_types.organization_id = projects.organization_id
        AND LOWER(item_types.name) = LOWER(items.item_type)
        AND items.item_type <> item_types.name
    SQL

    execute <<~SQL
      UPDATE statuses
      SET name = statuses.name || ' ' || statuses.id
      WHERE id IN (
        SELECT later.id
        FROM statuses later
        JOIN statuses earlier
          ON earlier.organization_id = later.organization_id
         AND LOWER(earlier.name) = LOWER(later.name)
         AND earlier.id < later.id
      )
    SQL

    add_index :statuses, "organization_id, LOWER(name)",
              unique: true, name: "index_statuses_on_organization_and_lower_name"
  end

  def down
    remove_index :statuses, name: "index_statuses_on_organization_and_lower_name"
  end
end
