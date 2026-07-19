class AddEmailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email, :string

    # Unique per non-null value (case-insensitive). Existing accounts may sit
    # without an email until they add one; new signups require it (model-level).
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email",
              where: "email IS NOT NULL"
  end
end
