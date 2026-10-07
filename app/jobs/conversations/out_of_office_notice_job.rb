# The bot answers at any hour, so the customer only needs to hear "we are closed" when the bot
# hands them to a seller who is not there. Sent a moment after the handoff, so it lands under
# the bot's own "I'm passing you to a seller" instead of above it.
class Conversations::OutOfOfficeNoticeJob < ApplicationJob
  queue_as :low

  WAIT = 20.seconds

  def perform(conversation)
    inbox = conversation.inbox
    return unless conversation.open? && conversation.assignee_agent_bot_id.blank?
    return unless inbox.out_of_office? && inbox.out_of_office_message.present?
    # Once a day per conversation, the same rule the inbox applies on its own.
    return if conversation.messages.today.template.exists?

    MessageTemplates::Template::OutOfOffice.new(conversation: conversation).perform
  end
end
