require 'rails_helper'

RSpec.describe Conversations::ReleaseBotJob do
  let(:bot_inbox) { create(:agent_bot_inbox) }
  let(:inbox) { bot_inbox.inbox }
  let!(:held) { create(:conversation, account: inbox.account, inbox: inbox) }

  it 'hands the conversations the bot held to the sellers when it is disconnected' do
    expect(held.reload).to have_attributes(status: 'pending', assignee_agent_bot: bot_inbox.agent_bot)

    perform_enqueued_jobs(only: described_class) { bot_inbox.destroy! }

    expect(held.reload).to have_attributes(status: 'open', assignee_agent_bot: nil)
  end
end
