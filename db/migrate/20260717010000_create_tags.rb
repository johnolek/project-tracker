class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.references :organization, null: false, foreign_key: true
      t.citext :name, null: false

      t.timestamps
    end
    add_index :tags, [ :organization_id, :name ], unique: true

    create_table :item_tags do |t|
      t.references :item, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    add_index :item_tags, [ :item_id, :tag_id ], unique: true
  end
end
