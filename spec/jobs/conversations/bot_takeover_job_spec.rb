require 'rails_helper'

RSpec.describe Conversations::BotTakeoverJob do
  let(:bot_inbox) { create(:agent_bot_inbox) }
  let(:inbox) { bot_inbox.inbox }
  let(:account) { inbox.account }
  let(:bot) { bot_inbox.agent_bot }
  let(:returning) { create(:contact, account: account).tap { |c| create(:conversation, account: account, inbox: inbox, contact: c) } }

  def open_shop(open)
    inbox.update!(working_hours_enabled: true)
    inbox.working_hours.update_all(open_all_day: open, closed_all_day: !open) # rubocop:disable Rails/SkipsModelValidations
  end

  describe 'who gets the conversation first' do
    it 'gives a returning customer to the sellers in business hours and schedules the bot' do
      open_shop(true)

      contact = returning
      conversation = nil

      expect { conversation = create(:conversation, account: account, inbox: inbox, contact: contact) }
        .to have_enqueued_job(described_class)
      expect(conversation).to have_attributes(status: 'open', assignee_agent_bot: nil)
    end

    it 'gives a new customer to the bot' do
      open_shop(true)
      conversation = create(:conversation, account: account, inbox: inbox)

      expect(conversation).to have_attributes(status: 'pending', assignee_agent_bot: bot)
    end

    it 'gives everyone to the bot outside business hours' do
      open_shop(false)
      conversation = create(:conversation, account: account, inbox: inbox, contact: returning)

      expect(conversation).to have_attributes(status: 'pending', assignee_agent_bot: bot)
    end
  end

  describe '#perform' do
    let(:conversation) do
      open_shop(true)
      create(:conversation, account: account, inbox: inbox, contact: returning)
    end

    before { create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming, content: 'precio?') }

    it 'hands the conversation to the bot and replays what the customer wrote' do
      expect { described_class.perform_now(conversation) }.to have_enqueued_job(AgentBots::WebhookJob).once

      expect(conversation.reload).to have_attributes(status: 'pending', assignee_agent_bot: bot, assignee: nil)
    end

    it 'stays out when a seller answered, even from the phone app' do
      create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :outgoing, sender: nil,
                       content_attributes: { external_echo: true })

      expect { described_class.perform_now(conversation) }.not_to have_enqueued_job(AgentBots::WebhookJob)
      expect(conversation.reload.assignee_agent_bot).to be_nil
    end

    it 'stays out of a closed conversation' do
      conversation.resolved!

      described_class.perform_now(conversation)

      expect(conversation.reload.assignee_agent_bot).to be_nil
    end
  end
end
