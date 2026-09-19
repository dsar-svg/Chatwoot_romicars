# frozen_string_literal: true

class CreateLocationCities < ActiveRecord::Migration[7.0]
  def change
    create_table :location_cities do |t|
      t.references :location_state, null: false, foreign_key: { on_delete: :cascade }
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :location_cities, [:location_state_id, :name], unique: true
    add_index :location_cities, [:account_id, :active]
  end
end
