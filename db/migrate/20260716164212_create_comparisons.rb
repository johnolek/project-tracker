class CreateComparisons < ActiveRecord::Migration[8.1]
  def change
    create_table :comparisons do |t|
      t.references :item_a, null: false, foreign_key: { to_table: :items }
      t.references :item_b, null: false, foreign_key: { to_table: :items }
      t.references :user, null: false, foreign_key: true
      t.string :outcome, null: false

      t.timestamps
    end
  end
end
