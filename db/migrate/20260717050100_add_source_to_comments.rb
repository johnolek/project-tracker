class AddSourceToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :source, :string, null: false, default: "web"
  end
end
