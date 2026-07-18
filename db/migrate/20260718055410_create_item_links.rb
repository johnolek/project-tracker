class CreateItemLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :item_links do |t|
      t.references :source, null: false, foreign_key: { to_table: :items }
      t.references :target, null: false, foreign_key: { to_table: :items }
      t.string :kind, null: false
      t.timestamps
    end

    add_index :item_links, %i[source_id target_id kind], unique: true
  end
end
