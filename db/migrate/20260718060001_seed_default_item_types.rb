class SeedDefaultItemTypes < ActiveRecord::Migration[8.1]
  # Backfills every existing organization with the three types the app shipped as
  # the hardcoded Item::ITEM_TYPES constant, each carrying the hex the Southwest
  # theme currently resolves Bulma danger/success/warning to so existing items
  # render unchanged. Idempotent: skips types an org already has (case-insensitive).
  DEFAULTS = [
    { name: "bug", color: "#9D2925", position: 1 },
    { name: "feature", color: "#4C633B", position: 2 },
    { name: "idea", color: "#F5AE0A", position: 3 }
  ].freeze

  class MigrationOrganization < ActiveRecord::Base
    self.table_name = "organizations"
  end

  class MigrationItemType < ActiveRecord::Base
    self.table_name = "item_types"
  end

  def up
    now = Time.current

    MigrationOrganization.find_each do |organization|
      DEFAULTS.each do |attributes|
        already_present = MigrationItemType
                          .where(organization_id: organization.id)
                          .where("lower(name) = ?", attributes[:name])
                          .exists?
        next if already_present

        MigrationItemType.create!(attributes.merge(organization_id: organization.id, created_at: now, updated_at: now))
      end
    end
  end

  def down
    MigrationItemType.delete_all
  end
end
