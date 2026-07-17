class RemovePublicSurface < ActiveRecord::Migration[8.1]
  def up
    remove_column :items, :source
    remove_column :items, :submitter_name
    remove_column :items, :submitter_email
    remove_column :projects, :public_token
  end

  def down
    add_column :items, :source, :string, default: "internal", null: false
    add_column :items, :submitter_name, :string
    add_column :items, :submitter_email, :string

    add_column :projects, :public_token, :string
    project = Class.new(ActiveRecord::Base) { self.table_name = "projects" }
    project.where(public_token: nil).find_each do |record|
      record.update_columns(public_token: SecureRandom.base58(24))
    end
    change_column_null :projects, :public_token, false
    add_index :projects, :public_token, unique: true
  end
end
