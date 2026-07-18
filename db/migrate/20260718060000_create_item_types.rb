class CreateItemTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :item_types do |t|
      t.references :organization, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.string :color, null: false
      t.integer :position, null: false

      t.timestamps
    end

    add_index :item_types, "organization_id, lower(name)", unique: true, name: "index_item_types_on_organization_id_and_lower_name"
  end
end
