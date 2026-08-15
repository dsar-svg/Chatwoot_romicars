# frozen_string_literal: true

class CreateVehicleBrands < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_brands do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :vehicle_brands, [:account_id, :name], unique: true
    add_index :vehicle_brands, [:account_id, :active]
  end
end
