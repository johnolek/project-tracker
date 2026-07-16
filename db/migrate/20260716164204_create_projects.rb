class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :public_token, null: false

      t.timestamps
    end

    add_index :projects, :public_token, unique: true
  end
end
