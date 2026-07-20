class AddAppearanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :color_scheme, :string, null: false, default: "southwest"
    add_column :users, :theme_mode, :string, null: false, default: "auto"
  end
end
