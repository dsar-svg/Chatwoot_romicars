# frozen_string_literal: true

class CreateConversationFollowups < ActiveRecord::Migration[7.0]
  def change
    create_table :conversation_followups do |t|
      # The unique index below already covers conversation_id as its leading column.
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :account, null: false, foreign_key: { on_delete: :cascade }

      t.string :etapa, null: false
      t.string :status, null: false, default: 'pending'
      t.string :mode, null: false, default: 'auto'
      t.integer :attempt, null: false, default: 1

      t.text :motivo
      t.text :mensaje

      t.datetime :scheduled_at, null: false
      t.datetime :sent_at
      t.datetime :cancelled_at
      t.string :cancel_reason

      t.timestamps
    end

    # The scheduler runs every 15 minutes and can overlap with itself on a slow tick.
    # Without this, a conversation gets two follow-ups and the customer gets nagged twice.
    add_index :conversation_followups, [:conversation_id, :attempt], unique: true,
                                                                     name: 'idx_followups_conversation_attempt'

    # The scheduler's hot query: rows that are due. Partial, because everything that has
    # already been sent or cancelled is dead weight it never looks at again.
    add_index :conversation_followups, :scheduled_at, where: "status = 'pending'",
                                                      name: 'idx_followups_pending_due'
  end
end
