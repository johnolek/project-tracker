class AddDefaultItemTypeToEmbedDomains < ActiveRecord::Migration[8.1]
  def change
    add_column :embed_domains, :default_item_type, :string
  end
end
