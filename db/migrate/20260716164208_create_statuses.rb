class CreateStatuses < ActiveRecord::Migration[8.1]
  def change
    create_table :statuses do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      t.string :category, null: false

      t.timestamps
    end
  end
end
