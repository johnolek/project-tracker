# PROJ-76 follow-up: the signup toggle is an admin setting in the DB, not an
# env var. Singleton row; allow_signups is tri-state (nil = automatic).
class CreateAppSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :app_settings do |t|
      t.boolean :allow_signups
      t.timestamps
    end
  end
end
