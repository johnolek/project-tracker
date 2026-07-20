# The Settings -> Admin page governs instance-wide switches, so "admin" is now
# a real flag instead of "any signed-in account". The earliest account (the
# instance owner) is backfilled as admin; User grants it automatically to the
# first account ever created, so fresh deploys bootstrap cleanly.
class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :admin, :boolean, null: false, default: false
    execute "UPDATE users SET admin = TRUE WHERE id = (SELECT id FROM users ORDER BY created_at, id LIMIT 1)"
  end

  def down
    remove_column :users, :admin
  end
end
