class AddProvenanceToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :source, :string, null: false, default: "web"
    add_column :items, :ai_reviewed_at, :datetime
  end
end
