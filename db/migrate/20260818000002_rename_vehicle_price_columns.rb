# frozen_string_literal: true

class RenameVehiclePriceColumns < ActiveRecord::Migration[7.0]
  def change
    rename_column :vehicle_prices, :divisor, :divisa
    rename_column :vehicle_prices, :cost_bs, :monto_bs
  end
end
