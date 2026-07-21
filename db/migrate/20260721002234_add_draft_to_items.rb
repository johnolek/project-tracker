class AddDraftToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :draft, :boolean, default: false, null: false
  end
end
