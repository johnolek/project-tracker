class ReplaceEloWithGlickoOnItems < ActiveRecord::Migration[8.1]
  def change
    remove_column :items, :elo_rating, :integer, null: false, default: 1000

    add_column :items, :rating, :float, null: false, default: 1500.0
    add_column :items, :rating_deviation, :float, null: false, default: 350.0
    add_column :items, :volatility, :float, null: false, default: 0.06
  end
end
