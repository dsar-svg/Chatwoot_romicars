# A returning customer wrote in business hours and the conversation went to the sellers first
# (Conversation#seller_first?). If none of them answered, from Chatwoot or from the phone app,
# the bot takes the conversation and answers what the customer already wrote.
class Conversations::BotTakeoverJob < ApplicationJob
  queue_as :default

  # The bot treats messages that arrive together as one, so a few is enough to give it context.
  REPLAYED_MESSAGES = 5

  def perform(conversation)
    return unless conversation.open? && conversation.assignee_agent_bot_id.blank?
    # Echoes from the WhatsApp app on the phone have no sender.
    return if conversation.messages.outgoing.where(private: false, sender_type: [nil, 'User']).exists?

    bot = takeover_bot(conversation)
    return if bot&.outgoing_url.blank?

    conversation.update!(assignee: nil, assignee_agent_bot: bot, status: :pending)
    conversation.messages.incoming.order(:id).last(REPLAYED_MESSAGES).each { |message| replay(bot, message) }
  end

  private

  # Only the inbox's own bot: if it was disconnected while the customer waited, the sellers keep the
  # conversation. A tester (prueba-bot) gets the account's bot on any inbox, as on creation.
  def takeover_bot(conversation)
    return conversation.inbox.agent_bot if conversation.inbox.agent_bot_inbox&.active?
    return unless conversation.contact.label_list.include?(Conversation::BOT_TESTER_LABEL)

    AgentBotInbox.active.where(account_id: conversation.account_id).order(:id).first&.agent_bot
  end

  # The same delivery AgentBotListener makes for a new message; the payload is built now, so it
  # already shows the bot as the assignee and the workflow answers it.
  def replay(bot, message)
    AgentBots::WebhookJob.perform_later(bot.outgoing_url, message.webhook_data.merge(event: 'message_created'),
                                        :agent_bot_webhook, secret: bot.secret, delivery_id: SecureRandom.uuid)
  end
end
