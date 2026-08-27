# frozen_string_literal: true

# Every RomiCars dashboard endpoint filters conversations by `resolved_at`, and there was
# no index on it — only on resolution_type and resolution_reason. It mattered little while
# resolved_at was almost always NULL; now that it is stamped on every resolution the
# filter matches real volume.
#
# Partial on `status = 1` (resolved) because that is the only status these queries ask
# for, which keeps the index small.
class AddResolvedAtIndexToConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :conversations, [:account_id, :resolved_at],
              where: 'status = 1',
              name: 'index_conversations_on_account_id_and_resolved_at',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
