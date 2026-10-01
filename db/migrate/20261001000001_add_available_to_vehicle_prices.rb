# frozen_string_literal: true

# Out of stock is not the same as inactive: an inactive price is hidden from the bot,
# an unavailable one is still found so the bot can say it is sold out.
class AddAvailableToVehiclePrices < ActiveRecord::Migration[7.1]
  def change
    add_column :vehicle_prices, :available, :boolean, default: true, null: false
  end
end
