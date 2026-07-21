class AddMetadataToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :metadata, :jsonb, default: {}, null: false
  end
end
