class MoveItemNotesToActionText < ActiveRecord::Migration[8.1]
  def up
    say_with_time("copying items.notes into action_text_rich_texts") do
      select_rows("SELECT id, notes FROM items WHERE notes IS NOT NULL AND notes <> ''").each do |id, notes|
        paragraphs = notes.split(/\n{2,}/).map do |paragraph|
          "<p>#{ERB::Util.html_escape(paragraph.strip).gsub("\n", "<br>")}</p>"
        end

        execute(<<~SQL)
          INSERT INTO action_text_rich_texts (name, body, record_type, record_id, created_at, updated_at)
          VALUES ('notes', #{connection.quote(paragraphs.join)}, 'Item', #{id.to_i}, NOW(), NOW())
        SQL
      end
    end

    remove_column :items, :notes
  end

  def down
    add_column :items, :notes, :text

    say_with_time("restoring items.notes from action_text_rich_texts (HTML bodies)") do
      execute(<<~SQL)
        UPDATE items
        SET notes = rich_texts.body
        FROM action_text_rich_texts rich_texts
        WHERE rich_texts.record_type = 'Item'
          AND rich_texts.name = 'notes'
          AND rich_texts.record_id = items.id
      SQL

      execute("DELETE FROM action_text_rich_texts WHERE record_type = 'Item' AND name = 'notes'")
    end
  end
end
