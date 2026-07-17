class ReplaceGlickoWithBradleyTerryStrength < ActiveRecord::Migration[8.1]
  def up
    remove_column :items, :rating
    remove_column :items, :rating_deviation
    remove_column :items, :volatility
    add_column :items, :strength, :float, null: false, default: 0.0
  end

  def down
    remove_column :items, :strength
    add_column :items, :rating, :float, null: false, default: 1500.0
    add_column :items, :rating_deviation, :float, null: false, default: 350.0
    add_column :items, :volatility, :float, null: false, default: 0.06
  end
end
