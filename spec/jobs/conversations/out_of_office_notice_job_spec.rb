require 'rails_helper'

RSpec.describe Conversations::OutOfOfficeNoticeJob do
  let(:conversation) { create(:conversation, status: :open) }
  let(:inbox) { conversation.inbox }

  before do
    inbox.update!(working_hours_enabled: true, out_of_office_message: 'Estamos fuera de horario')
    inbox.working_hours.update_all(closed_all_day: true, open_all_day: false) # rubocop:disable Rails/SkipsModelValidations
  end

  it 'tells the customer the shop is closed, once' do
    described_class.perform_now(conversation)
    described_class.perform_now(conversation)

    expect(conversation.messages.template.pluck(:content)).to eq(['Estamos fuera de horario'])
  end

  it 'says nothing while the shop is open' do
    inbox.working_hours.update_all(closed_all_day: false, open_all_day: true) # rubocop:disable Rails/SkipsModelValidations

    described_class.perform_now(conversation)

    expect(conversation.messages.template).to be_empty
  end

  it 'says nothing while the bot still holds the conversation' do
    conversation.update!(assignee_agent_bot: create(:agent_bot, account: conversation.account))

    described_class.perform_now(conversation)

    expect(conversation.messages.template).to be_empty
  end

  it 'is queued when the bot hands off outside working hours' do
    conversation.update!(status: :pending, assignee_agent_bot: create(:agent_bot, account: conversation.account))

    expect { conversation.bot_handoff! }.to have_enqueued_job(described_class).with(conversation)
  end
end
