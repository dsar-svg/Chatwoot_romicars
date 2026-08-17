# frozen_string_literal: true

class AddSaleFieldsToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :sale_amount, :decimal, precision: 12, scale: 2
    add_column :conversations, :sale_date, :date
    add_column :conversations, :sale_invoice, :string
  end
end
