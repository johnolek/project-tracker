class AddDefaultPointsToEmbedDomains < ActiveRecord::Migration[8.1]
  def change
    add_column :embed_domains, :default_points, :integer
  end
end
