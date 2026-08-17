# frozen_string_literal: true

class AddSynonymsToVehiclePrices < ActiveRecord::Migration[7.0]
  def change
    add_column :vehicle_prices, :synonyms, :text

    add_index :vehicle_prices, :description,
              using: :gin,
              opclass: :gin_trgm_ops,
              name: 'index_vehicle_prices_on_description_trgm'

    add_index :vehicle_prices, :synonyms,
              using: :gin,
              opclass: :gin_trgm_ops,
              name: 'index_vehicle_prices_on_synonyms_trgm'
  end
end
