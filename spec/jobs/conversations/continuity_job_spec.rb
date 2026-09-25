require 'rails_helper'

RSpec.describe Conversations::ContinuityJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, name: 'Instagram Romicars') }
  let(:contact) { create(:contact, account: account) }

  def conversation_for(contact, **attrs)
    create(:conversation, account: account, inbox: inbox, contact: contact, **attrs)
  end

  it 'ties a new conversation to the one the customer had last week' do
    previous = conversation_for(contact, status: :resolved, resolution_type: 'abandonado', last_activity_at: 3.days.ago)
    create(:product_inquiry, conversation: previous, account: account, repuesto_buscado: 'kit de clutch', encontrado: true)
    current = conversation_for(contact)

    described_class.perform_now(current)

    expect(current.reload.custom_attributes['continua_de']).to eq(previous.display_id)
    expect(current.messages.activity.last.content)
      .to include("##{previous.display_id}", 'pidió kit de clutch', 'cerrada: sin respuesta')
  end

  it 'leaves alone a customer whose last conversation is older than two weeks' do
    conversation_for(contact, last_activity_at: 20.days.ago)
    current = conversation_for(contact)

    described_class.perform_now(current)

    expect(current.reload.custom_attributes).not_to have_key('continua_de')
  end

  it 'leaves the WhatsApp handoff to its own note' do
    conversation_for(contact, status: :resolved, resolution_type: 'derivado', last_activity_at: 1.hour.ago)
    current = conversation_for(contact)

    described_class.perform_now(current)

    expect(current.reload.custom_attributes).not_to have_key('continua_de')
  end

  it 'is queued for every new conversation' do
    expect { conversation_for(contact) }.to have_enqueued_job(described_class)
  end
end
