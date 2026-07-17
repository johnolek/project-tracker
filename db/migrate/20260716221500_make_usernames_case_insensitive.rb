class MakeUsernamesCaseInsensitive < ActiveRecord::Migration[8.1]
  def up
    enable_extension "citext"
    change_column :users, :username, :citext
  end

  def down
    change_column :users, :username, :string
    disable_extension "citext"
  end
end
