# frozen_string_literal: true

class CreateBotLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :bot_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: true
      t.references :contact, null: true, foreign_key: true
      t.string :tipo_evento, null: false, limit: 50
      t.string :severidad, null: false, default: 'info', limit: 10
      t.text :detalle
      t.string :accion_intentada, limit: 100
      t.jsonb :contexto

      t.timestamps
    end

    add_index :bot_logs, [:account_id, :tipo_evento]
    add_index :bot_logs, [:account_id, :severidad]
    add_index :bot_logs, [:account_id, :created_at]
    add_index :bot_logs, :tipo_evento
    add_index :bot_logs, :severidad
    add_index :bot_logs, :created_at
  end
end
