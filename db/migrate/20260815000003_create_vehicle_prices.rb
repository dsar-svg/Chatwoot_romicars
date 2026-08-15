# frozen_string_literal: true

class CreateVehiclePrices < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_prices do |t|
      t.references :account, null: false, foreign_key: true
      t.references :vehicle_brand, null: false, foreign_key: true
      t.references :vehicle_model, null: true, foreign_key: true
      t.text :description, null: false
      t.string :variant
      t.decimal :cost_usd, precision: 10, scale: 2
      t.integer :divisor
      t.decimal :cost_bs, precision: 12, scale: 2
      t.integer :bolivares
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :vehicle_prices, [:account_id, :active]
    add_index :vehicle_prices, [:account_id, :vehicle_brand_id]
    add_index :vehicle_prices, [:account_id, :vehicle_model_id]
  end
end
