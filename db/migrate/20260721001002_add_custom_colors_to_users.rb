class AddCustomColorsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :custom_colors, :jsonb
  end
end
