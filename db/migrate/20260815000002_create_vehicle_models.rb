# frozen_string_literal: true

class CreateVehicleModels < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_models do |t|
      t.references :vehicle_brand, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :vehicle_models, [:vehicle_brand_id, :name], unique: true
    add_index :vehicle_models, [:account_id, :active]
  end
end
