# frozen_string_literal: true

class CreateExchangeRates < ActiveRecord::Migration[7.0]
  def change
    create_table :exchange_rates do |t|
      t.references :account, null: false, foreign_key: true
      t.decimal :rate, precision: 10, scale: 2, null: false
      t.decimal :equiv_13, precision: 10, scale: 2
      t.date :effective_date, null: false
      t.string :source

      t.timestamps
    end

    add_index :exchange_rates, [:account_id, :effective_date], unique: true
  end
end
