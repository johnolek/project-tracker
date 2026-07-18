class CreateProjectSlugAliases < ActiveRecord::Migration[8.1]
  def change
    create_table :project_slug_aliases do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.references :organization, null: false, foreign_key: true
      t.string :slug, null: false

      t.timestamps
    end

    # A retired slug is reserved org-wide: no active project slug and no other
    # retired slug may reuse it (case-insensitive, matching Project slug rules).
    add_index :project_slug_aliases, "organization_id, lower(slug)", unique: true,
              name: "index_project_slug_aliases_on_org_and_lower_slug"
  end
end
