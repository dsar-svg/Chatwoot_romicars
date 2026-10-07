# frozen_string_literal: true

# Combos and promotions live in the price list next to the parts, so they share the bolivar
# repricing and the edit screens. A promotion can cover every brand, hence the nullable brand.
class AddKindToVehiclePrices < ActiveRecord::Migration[7.1]
  def change
    add_column :vehicle_prices, :kind, :string, default: 'repuesto', null: false
    add_column :vehicle_prices, :details, :text
    add_column :vehicle_prices, :ends_on, :date
    change_column_null :vehicle_prices, :vehicle_brand_id, true
    add_index :vehicle_prices, [:account_id, :kind]
  end
end
