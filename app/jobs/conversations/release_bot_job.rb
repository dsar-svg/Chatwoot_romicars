# The bot was disconnected from an inbox: the conversations it still holds there go to the sellers.
class Conversations::ReleaseBotJob < ApplicationJob
  queue_as :default

  def perform(inbox_id, agent_bot_id)
    Conversation.where(inbox_id: inbox_id, assignee_agent_bot_id: agent_bot_id)
                .where.not(status: :resolved)
                .find_each(&:bot_handoff!)
  end
end
