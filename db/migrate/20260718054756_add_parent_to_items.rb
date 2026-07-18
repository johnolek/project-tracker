class AddParentToItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :items, :parent, foreign_key: { to_table: :items }
  end
end
