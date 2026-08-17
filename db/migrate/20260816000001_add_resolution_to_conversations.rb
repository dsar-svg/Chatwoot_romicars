# frozen_string_literal: true

class AddResolutionToConversations < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :resolution_type, :string
    add_column :conversations, :resolution_reason, :string
    add_column :conversations, :resolution_notes, :text
    add_column :conversations, :resolved_at, :datetime

    add_index :conversations, [:account_id, :resolution_type]
    add_index :conversations, [:account_id, :resolution_reason]
  end
end
