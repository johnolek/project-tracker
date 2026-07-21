class CreateEmbedDomains < ActiveRecord::Migration[8.1]
  def change
    create_table :embed_domains do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.string :host, null: false

      t.timestamps
    end

    add_index :embed_domains, :host, unique: true
  end
end
