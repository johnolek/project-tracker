class AddProjectSlugsAndItemNumbers < ActiveRecord::Migration[8.1]
  class MigrationProject < ActiveRecord::Base
    self.table_name = "projects"
  end

  def up
    add_column :projects, :slug, :string
    add_column :projects, :last_item_number, :integer, default: 0, null: false
    add_column :items, :number, :integer

    backfill_slugs
    backfill_numbers

    change_column_null :projects, :slug, false
    change_column_null :items, :number, false
    add_index :projects, [ :organization_id, :slug ], unique: true
    add_index :items, [ :project_id, :number ], unique: true
  end

  def down
    remove_column :projects, :slug
    remove_column :projects, :last_item_number
    remove_column :items, :number
  end

  private

  # Mirrors Project.derive_slug at the time of this migration; deliberately
  # duplicated so the migration stays independent of app code.
  def backfill_slugs
    used = Hash.new { |hash, organization_id| hash[organization_id] = Set.new }

    MigrationProject.order(:id).each do |project|
      word = project.name.to_s.scan(/[A-Za-z0-9]+/).first.to_s
      base = word.upcase[0, 4]
      base = "P#{base}"[0, 10] unless base.match?(/\A[A-Z]/)

      candidate = base
      suffix = 2
      while used[project.organization_id].include?(candidate)
        candidate = "#{base[0, 10 - suffix.to_s.length]}#{suffix}"
        suffix += 1
      end

      used[project.organization_id] << candidate
      project.update_columns(slug: candidate)
    end
  end

  def backfill_numbers
    execute <<~SQL
      UPDATE items SET number = numbered.rn
      FROM (
        SELECT id, row_number() OVER (PARTITION BY project_id ORDER BY id) AS rn
        FROM items
      ) numbered
      WHERE items.id = numbered.id
    SQL

    execute <<~SQL
      UPDATE projects
      SET last_item_number = COALESCE(
        (SELECT MAX(number) FROM items WHERE items.project_id = projects.id), 0
      )
    SQL
  end
end
