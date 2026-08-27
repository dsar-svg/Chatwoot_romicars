# frozen_string_literal: true

# The RomiCars tables were created with `foreign_key: true`, which base Chatwoot almost
# never uses (its schema has four foreign keys in total). Chatwoot cleans children up
# with `dependent: :destroy_async`, which enqueues a job *after* the parent row is
# already gone — fine without constraints, a PG::ForeignKeyViolation with them.
#
# In practice that means deleting a conversation, a contact or an account raises as soon
# as it has a bot_log, a product_inquiry, a price or an FAQ attached. Pushing the cleanup
# down to the database fixes it for every deletion path at once.
class CascadeForeignKeysOnRomicarsTables < ActiveRecord::Migration[7.1]
  CASCADES = [
    [:faqs, :accounts, 'account_id'],
    [:vehicle_brands, :accounts, 'account_id'],
    [:vehicle_models, :accounts, 'account_id'],
    [:vehicle_models, :vehicle_brands, 'vehicle_brand_id'],
    [:vehicle_prices, :accounts, 'account_id'],
    [:vehicle_prices, :vehicle_brands, 'vehicle_brand_id'],
    [:exchange_rates, :accounts, 'account_id'],
    [:bot_logs, :accounts, 'account_id'],
    [:bot_logs, :conversations, 'conversation_id'],
    [:product_inquiries, :accounts, 'account_id'],
    [:product_inquiries, :conversations, 'conversation_id']
  ].freeze

  # Nullable references: keep the row, drop the link.
  NULLIFIES = [
    [:vehicle_prices, :vehicle_models, 'vehicle_model_id'],
    [:bot_logs, :contacts, 'contact_id']
  ].freeze

  def up
    CASCADES.each { |table, target, column| replace_fk(table, target, column, :cascade) }
    NULLIFIES.each { |table, target, column| replace_fk(table, target, column, :nullify) }
  end

  def down
    (CASCADES + NULLIFIES).each { |table, target, column| replace_fk(table, target, column, nil) }
  end

  private

  def replace_fk(table, target, column, on_delete)
    return unless table_exists?(table)
    return unless foreign_key_exists?(table, target, column: column)

    remove_foreign_key table, target, column: column
    add_foreign_key table, target, column: column, on_delete: on_delete
  end
end
