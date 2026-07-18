class ConsolidateItemTypesIntoFeature < ActiveRecord::Migration[8.1]
  def up
    change_column_default :items, :item_type, from: "task", to: "feature"
    execute "UPDATE items SET item_type = 'feature' WHERE item_type IN ('task', 'enhancement')"
  end

  # The task/enhancement split is not recoverable once merged; rolling back only
  # restores the old column default.
  def down
    change_column_default :items, :item_type, from: "feature", to: "task"
  end
end
