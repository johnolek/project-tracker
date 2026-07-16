class AddStatusToItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :items, :status, null: false, foreign_key: true
  end
end
