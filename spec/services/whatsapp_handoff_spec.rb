# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WhatsappHandoff do
  let(:account) { create(:account) }
  let!(:whatsapp_channel) do
    create(:channel_whatsapp, account: account, phone_number: '+584244205394', sync_templates: false, validate_provider_config: false)
  end
  let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }
  let(:instagram_inbox) { create(:inbox, account: account, name: 'Instagram Romicars') }
  let(:instagram_contact) do
    create(:contact, account: account, name: 'Ricardo', custom_attributes: { 'marca_vehiculo' => 'CHERY' })
  end
  let(:origin) { create(:conversation, account: account, inbox: instagram_inbox, contact: instagram_contact) }

  describe '.start' do
    it 'links to the shop number with the order and a code already written' do
      result = described_class.start(origin, repuesto: 'sensor de cigüeñal largo', vehiculo: 'Chery Orinoco')

      expect(result[:code]).to match(/\ARC-[A-Z2-9]{5}\z/)
      expect(result[:link]).to start_with('https://wa.me/584244205394?text=')
      expect(CGI.unescape(result[:link].split('text=').last))
        .to eq("Hola Romicars, quiero comprar sensor de cigüeñal largo para mi Chery Orinoco. Código #{result[:code]}")
      expect(origin.reload.custom_attributes).to include('wa_code' => result[:code], 'wa_repuesto' => 'sensor de cigüeñal largo')
      expect(origin.label_list).to include(described_class::LABEL)
    end

    it 'keeps the first code when the bot asks again, since that link may already be open' do
      first = described_class.start(origin)[:code]

      expect(described_class.start(origin.reload)[:code]).to eq(first)
    end

    it 'refuses when the account has no WhatsApp number to send them to' do
      whatsapp_channel.destroy!

      expect { described_class.start(origin) }.to raise_error(described_class::NoWhatsappInbox)
    end
  end

  describe '.claim' do
    let(:whatsapp_contact) { create(:contact, account: account, name: '.', phone_number: '+584141234567') }
    let(:arrival) do
      contact_inbox = create(:contact_inbox, contact: whatsapp_contact, inbox: whatsapp_inbox, source_id: '584141234567')
      create(:conversation, account: account, inbox: whatsapp_inbox, contact: whatsapp_contact, contact_inbox: contact_inbox)
    end

    def arrive_with(content)
      create(:message, account: account, inbox: whatsapp_inbox, conversation: arrival, message_type: :incoming, content: content)
    end

    it 'joins the two contacts and closes the Instagram side as derivado' do
      code = described_class.start(origin, repuesto: 'kit de clutch')[:code]

      described_class.claim(arrive_with("Hola Romicars, quiero comprar kit de clutch. Código #{code}"))

      # The WhatsApp contact survives with its verified number; the name the bot asked for
      # on Instagram replaces the profile name, and the vehicle comes along.
      survivor = whatsapp_contact.reload
      expect(survivor).to have_attributes(name: 'Ricardo', phone_number: '+584141234567')
      expect(survivor.custom_attributes).to include('marca_vehiculo' => 'CHERY')
      expect(Contact.exists?(instagram_contact.id)).to be(false)

      expect(origin.reload).to have_attributes(status: 'resolved', resolution_type: 'derivado', contact_id: survivor.id)
      expect(arrival.messages.activity.last.content).to include("##{origin.display_id}", 'kit de clutch')
    end

    it 'reads the code even when the customer retyped it in lowercase' do
      code = described_class.start(origin)[:code]

      described_class.claim(arrive_with("quiero el repuesto #{code.downcase}"))

      expect(origin.reload.resolution_type).to eq('derivado')
    end

    it 'does nothing for a code no conversation sent' do
      described_class.claim(arrive_with('Código RC-ZZZZZ'))

      expect(Contact.exists?(instagram_contact.id)).to be(true)
    end

    it 'queues the claim from the message itself, only for WhatsApp' do
      code = described_class.start(origin)[:code]

      expect { arrive_with("Código #{code}") }.to have_enqueued_job(Conversations::WhatsappHandoffArrivalJob)
      expect do
        create(:message, account: account, inbox: instagram_inbox, conversation: origin, message_type: :incoming, content: code)
      end.not_to have_enqueued_job(Conversations::WhatsappHandoffArrivalJob)
    end
  end

  describe '.save_phone' do
    it 'saves the number the way WhatsApp writes it' do
      described_class.save_phone(instagram_contact, '0414-123.45.67')

      expect(instagram_contact.reload.phone_number).to eq('+584141234567')
    end

    it 'joins the contact that already had that number instead of failing the uniqueness check' do
      existing = create(:contact, account: account, name: '🙂', phone_number: '+584141234567')

      survivor = described_class.save_phone(instagram_contact, '04141234567')

      expect(survivor).to eq(existing)
      expect(survivor.reload.name).to eq('Ricardo')
      expect(Contact.exists?(instagram_contact.id)).to be(false)
    end

    it 'rejects something that is not a phone number' do
      expect { described_class.save_phone(instagram_contact, '1234') }.to raise_error(described_class::InvalidPhone)
    end
  end

  describe '.normalize_phone' do
    it 'accepts the ways Venezuelans write a number' do
      expect(described_class.normalize_phone('0414 1234567')).to eq('+584141234567')
      expect(described_class.normalize_phone('414-1234567')).to eq('+584141234567')
      expect(described_class.normalize_phone('+58 414 123 4567')).to eq('+584141234567')
      expect(described_class.normalize_phone('584141234567')).to eq('+584141234567')
      expect(described_class.normalize_phone('0212-5551234')).to eq('+582125551234')
      expect(described_class.normalize_phone('+1 305 555 0100')).to eq('+13055550100')
      expect(described_class.normalize_phone('mañana te lo paso')).to be_nil
    end
  end
end
