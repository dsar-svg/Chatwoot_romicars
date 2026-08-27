# frozen_string_literal: true

# `resolved_at` was only stamped by Conversation#resolve_with_outcome, so every
# conversation closed by an automation, the bot, a macro or the plain resolve button
# kept it NULL and was invisible to the RomiCars dashboard metrics.
#
# Conversation#set_resolved_at now stamps it on every transition into `resolved`. This
# backfills the rows that predate that callback. It only fills NULLs — no existing value
# is overwritten — and falls back to updated_at for rows older than status_changed_at.
class BackfillResolvedAtOnConversations < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  # Decoupled from the Conversation model so a later enum change cannot silently
  # repoint this migration. 1 is `resolved`.
  RESOLVED_STATUS = 1

  def up
    loop do
      updated = execute(<<~SQL.squish).cmd_tuples
        UPDATE conversations SET resolved_at = COALESCE(status_changed_at, updated_at)
        WHERE id IN (
          SELECT id FROM conversations
          WHERE status = #{RESOLVED_STATUS} AND resolved_at IS NULL
          LIMIT 5000
        )
      SQL

      break if updated.zero?
    end
  end

  def down
    # Not reversible: the original NULLs carried no information worth restoring.
  end
end
