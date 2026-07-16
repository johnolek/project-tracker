class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :notes
      t.integer :points
      t.integer :elo_rating, null: false, default: 1000
      t.string :item_type, null: false, default: "task"
      t.string :source, null: false, default: "internal"
      t.string :submitter_name
      t.string :submitter_email

      t.timestamps
    end
  end
end
