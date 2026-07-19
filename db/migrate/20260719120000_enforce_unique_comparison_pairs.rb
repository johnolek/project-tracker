class EnforceUniqueComparisonPairs < ActiveRecord::Migration[8.1]
  # Each unordered pair only needs one comparison — Bradley-Terry gains nothing
  # from re-observing the same matchup. Collapse any historical duplicates
  # (either ordering) to the most recent one, then forbid new ones.
  def up
    # Keep the highest-id (most recent) row per unordered {item_a, item_b} pair.
    execute(<<~SQL)
      DELETE FROM comparisons c
      USING comparisons keep
      WHERE c.id < keep.id
        AND LEAST(c.item_a_id, c.item_b_id) = LEAST(keep.item_a_id, keep.item_b_id)
        AND GREATEST(c.item_a_id, c.item_b_id) = GREATEST(keep.item_a_id, keep.item_b_id)
    SQL

    add_index :comparisons,
              "LEAST(item_a_id, item_b_id), GREATEST(item_a_id, item_b_id)",
              unique: true,
              name: "index_comparisons_on_unordered_pair"

    # Strengths were fitted from data that may have included duplicates; refit.
    Organization.find_each { |org| Item.recompute_strengths(organization: org) } if defined?(Organization)
  end

  def down
    remove_index :comparisons, name: "index_comparisons_on_unordered_pair"
  end
end
