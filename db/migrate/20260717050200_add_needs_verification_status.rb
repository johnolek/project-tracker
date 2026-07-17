class AddNeedsVerificationStatus < ActiveRecord::Migration[8.1]
  STATUS_NAME = "Needs Verification".freeze

  def up
    say_with_time("inserting '#{STATUS_NAME}' status into existing organizations") do
      select_values("SELECT id FROM organizations").each do |organization_id|
        organization_id = organization_id.to_i
        next if status_named?(organization_id: organization_id, name: STATUS_NAME)

        position = insert_position(organization_id: organization_id)

        execute(<<~SQL.squish)
          UPDATE statuses SET position = position + 1, updated_at = NOW()
          WHERE organization_id = #{organization_id} AND position >= #{position}
        SQL

        execute(<<~SQL.squish)
          INSERT INTO statuses (organization_id, name, category, position, created_at, updated_at)
          VALUES (#{organization_id}, #{quote(STATUS_NAME)}, 'in_progress', #{position}, NOW(), NOW())
        SQL
      end
    end
  end

  def down
    say_with_time("removing '#{STATUS_NAME}' status and recompacting positions") do
      select_rows(<<~SQL.squish).each do |organization_id, position|
        SELECT organization_id, position FROM statuses WHERE name = #{quote(STATUS_NAME)}
      SQL
        execute(<<~SQL.squish)
          DELETE FROM statuses WHERE organization_id = #{organization_id.to_i} AND name = #{quote(STATUS_NAME)}
        SQL

        execute(<<~SQL.squish)
          UPDATE statuses SET position = position - 1, updated_at = NOW()
          WHERE organization_id = #{organization_id.to_i} AND position > #{position.to_i}
        SQL
      end
    end
  end

  private

  def status_named?(organization_id:, name:)
    select_value(<<~SQL.squish).present?
      SELECT 1 FROM statuses WHERE organization_id = #{organization_id} AND name = #{quote(name)} LIMIT 1
    SQL
  end

  # Position immediately after the org's "In Progress" status, matching the
  # default column order; falls back to the end of the list when absent.
  def insert_position(organization_id:)
    in_progress = select_value(<<~SQL.squish)
      SELECT position FROM statuses WHERE organization_id = #{organization_id} AND name = 'In Progress' LIMIT 1
    SQL
    return in_progress.to_i + 1 if in_progress

    select_value("SELECT MAX(position) FROM statuses WHERE organization_id = #{organization_id}").to_i + 1
  end

  def quote(value)
    connection.quote(value)
  end
end
