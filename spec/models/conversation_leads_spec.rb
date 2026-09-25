require 'rails_helper'

RSpec.describe Conversation do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:customer) { create(:contact, account: account) }
  let(:supplier) { create(:contact, account: account) }

  def conversation_for(contact)
    create(:conversation, account: account, inbox: inbox, contact: contact)
  end

  describe '.leads' do
    it 'leaves out a conversation tagged proveedor or logistica' do
      lead = conversation_for(customer)
      rider = conversation_for(customer).tap { |c| c.add_labels(['logistica']) }

      expect(account.conversations.leads).to contain_exactly(lead)
      expect(account.conversations.leads).not_to include(rider)
    end

    it 'leaves out every conversation of a contact tagged proveedor, including older ones' do
      old_thread = conversation_for(supplier)
      supplier.add_labels(['proveedor'])

      expect(account.conversations.leads).not_to include(old_thread)
    end
  end

  describe 'when the contact is a supplier' do
    before { supplier.add_labels(['proveedor']) }

    it 'tags each new conversation, so the seller sees why' do
      expect(conversation_for(supplier).reload.label_list).to include('proveedor')
    end

    it 'does not hand it to the bot' do
      bot_inbox = create(:inbox, account: account)
      create(:agent_bot_inbox, inbox: bot_inbox)

      conversation = create(:conversation, account: account, inbox: bot_inbox, contact: supplier)

      expect(conversation.assignee_agent_bot).to be_nil
      expect(conversation.status).to eq('open')
    end
  end

  describe 'tagging a conversation' do
    it 'marks the contact as a supplier from one proveedor tag' do
      conversation_for(supplier).update_labels(['proveedor'])

      expect(supplier.reload.label_list).to include('proveedor')
    end

    # A customer's own thread can be about their delivery; that does not make them the rider.
    it 'keeps logistica on the conversation only' do
      conversation_for(customer).update_labels(['logistica'])

      expect(customer.reload.label_list).not_to include('logistica')
    end
  end
end
