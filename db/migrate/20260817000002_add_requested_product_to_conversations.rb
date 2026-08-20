# frozen_string_literal: true

class AddRequestedProductToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :requested_product, :string
  end
end
