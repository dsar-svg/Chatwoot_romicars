# frozen_string_literal: true

class CreateLocationStates < ActiveRecord::Migration[7.0]
  def change
    create_table :location_states do |t|
      t.references :account, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :location_states, [:account_id, :name], unique: true
    add_index :location_states, [:account_id, :active]
  end
end
