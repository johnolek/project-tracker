class AddReviewFlagToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :review_requested_at, :datetime
    add_column :items, :review_note, :text

    # Partial index: the review queue only ever asks for the flagged rows, which
    # are the small minority, so index just those.
    add_index :items, :review_requested_at, where: "review_requested_at IS NOT NULL",
              name: "index_items_on_review_requested_at"
  end
end
