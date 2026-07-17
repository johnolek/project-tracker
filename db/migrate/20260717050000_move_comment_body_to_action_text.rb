class MoveCommentBodyToActionText < ActiveRecord::Migration[8.1]
  def up
    say_with_time("copying comments.body into action_text_rich_texts") do
      select_rows("SELECT id, body FROM comments WHERE body IS NOT NULL AND body <> ''").each do |id, body|
        paragraphs = body.split(/\n{2,}/).map do |paragraph|
          "<p>#{ERB::Util.html_escape(paragraph.strip).gsub("\n", "<br>")}</p>"
        end

        execute(<<~SQL)
          INSERT INTO action_text_rich_texts (name, body, record_type, record_id, created_at, updated_at)
          VALUES ('body', #{connection.quote(paragraphs.join)}, 'Comment', #{id.to_i}, NOW(), NOW())
        SQL
      end
    end

    remove_column :comments, :body
  end

  def down
    add_column :comments, :body, :text

    say_with_time("restoring comments.body from action_text_rich_texts (HTML bodies)") do
      execute(<<~SQL)
        UPDATE comments
        SET body = rich_texts.body
        FROM action_text_rich_texts rich_texts
        WHERE rich_texts.record_type = 'Comment'
          AND rich_texts.name = 'body'
          AND rich_texts.record_id = comments.id
      SQL

      execute("DELETE FROM action_text_rich_texts WHERE record_type = 'Comment' AND name = 'body'")
    end

    change_column_null :comments, :body, false, ""
  end
end
