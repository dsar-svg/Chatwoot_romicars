class Conversations::ReopenSnoozedConversationsJob < ApplicationJob
  queue_as :low

  def perform
    Conversation.where(status: :snoozed).where(snoozed_until: 3.days.ago..Time.current).all.find_each(batch_size: 100) do |conversation|
      # The bot snoozes until the day the customer said they would buy. That day the
      # conversation is for a seller: left with the bot it opens assigned to nobody.
      conversation.assignee_agent_bot_id.present? ? conversation.bot_handoff! : conversation.open!
    end
  end
end
