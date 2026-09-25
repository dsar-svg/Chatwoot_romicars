# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationFollowupsJob do
  subject(:job) { described_class.new }

  # The job ships dormant: an admin switches it on per account. Every example here runs
  # with it on; the off case is its own test below.
  let(:account) { create(:account, settings: { 'followups_enabled' => true }) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'Ricardo') }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

  # 2pm Caracas: inside the send window, so the window is never what makes a test pass.
  let(:midday) { Time.zone.local(2026, 9, 21, 14, 0) }

  # A conversation the customer opened, we answered, and then went quiet on.
  def quiet_conversation(**attrs)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact,
                                         contact_inbox: contact_inbox, status: :open, **attrs)
    create(:message, conversation: conversation, account: account, message_type: :incoming,
                     created_at: 7.hours.ago)
    create(:message, conversation: conversation, account: account, message_type: :outgoing,
                     created_at: 6.hours.ago)
    conversation.update!(waiting_since: nil, last_activity_at: 6.hours.ago)
    conversation
  end

  describe 'scheduling' do
    it 'schedules one follow-up for a conversation that went quiet' do
      conversation = nil
      travel_to(midday) do
        conversation = quiet_conversation
        job.perform
      end

      # Inside the send window it goes out in the same tick; the night case stays pending and
      # has its own example below.
      followup = ConversationFollowup.find_by(conversation: conversation)
      expect(followup).to have_attributes(status: 'sent', mode: 'auto', attempt: 1)
    end

    it 'leaves alone a conversation where we are the ones who owe a reply' do
      travel_to(midday) do
        quiet_conversation.update!(waiting_since: 6.hours.ago)
        job.perform
      end

      expect(ConversationFollowup.count).to eq(0)
    end

    it 'leaves alone a thread tagged as not a lead' do
      travel_to(midday) do
        quiet_conversation.add_labels(['proveedor'])
        job.perform
      end

      expect(ConversationFollowup.count).to eq(0)
    end

    it 'waits the hours of silence the account set instead of the default five' do
      account.update!(settings: account.settings.merge('followups_silence_hours' => 2))
      travel_to(midday) do
        quiet_conversation.update!(last_activity_at: 3.hours.ago)
        job.perform
      end

      expect(ConversationFollowup.count).to eq(1)
    end

    it 'holds an out-of-range silence to the cap, so the nudge still lands inside the 24h window' do
      account.update!(settings: account.settings.merge('followups_silence_hours' => 40))
      travel_to(midday) do
        quiet_conversation.update!(last_activity_at: 13.hours.ago)
        job.perform
      end

      expect(ConversationFollowup.count).to eq(1)
    end

    it 'leaves alone a conversation that is still warm' do
      travel_to(midday) do
        quiet_conversation.update!(last_activity_at: 1.hour.ago)
        job.perform
      end

      expect(ConversationFollowup.count).to eq(0)
    end

    it 'leaves alone a conversation that already ended in a sale' do
      travel_to(midday) do
        quiet_conversation.update!(sale_amount: 120)
        job.perform
      end

      expect(ConversationFollowup.count).to eq(0)
    end

    it 'never schedules a second one for the same conversation' do
      travel_to(midday) do
        quiet_conversation
        job.perform
        job.perform
      end

      expect(ConversationFollowup.count).to eq(1)
    end

    it 'skips a contact who opted out' do
      travel_to(midday) do
        quiet_conversation
        contact.update!(custom_attributes: { 'followups_opt_out' => 'true' })
        job.perform
      end

      expect(ConversationFollowup.count).to eq(0)
    end

    it 'marks it assisted when a seller already owns the conversation' do
      agent = create(:user, account: account)
      travel_to(midday) do
        quiet_conversation.update!(assignee: agent)
        job.perform
      end

      expect(ConversationFollowup.last.mode).to eq('assisted')
    end
  end

  describe 'sending' do
    it 'sends the nudge and names the part the customer asked for' do
      conversation = nil
      travel_to(midday) do
        conversation = quiet_conversation
        create(:product_inquiry, conversation: conversation, account: account,
                                 repuesto_buscado: 'kit de clutch', encontrado: true)
        job.perform
      end

      followup = ConversationFollowup.last
      expect(followup.status).to eq('sent')
      expect(followup.mensaje).to include('Ricardo', 'kit de clutch')
      expect(conversation.messages.where(message_type: :outgoing).last.content).to eq(followup.mensaje)
    end

    it 'signs the nudge with the bot the customer has been talking to' do
      agent_bot = create(:agent_bot, account: account, name: 'Carlos Asesor')
      conversation = nil
      travel_to(midday) do
        conversation = quiet_conversation
        create(:agent_bot_inbox, inbox: inbox, agent_bot: agent_bot)
        job.perform
      end

      # Without a sender the dashboard labels the bubble with a bare "Bot".
      expect(conversation.messages.where(message_type: :outgoing).last.sender).to eq(agent_bot)
    end

    it 'sends the text the shop wrote, with the part filled in and the name in front' do
      account.update!(settings: account.settings.merge('followups_message_cotizado' => 'el {repuesto} sigue apartado, ¿lo buscas hoy?'))
      travel_to(midday) do
        conversation = quiet_conversation
        create(:product_inquiry, conversation: conversation, account: account,
                                 repuesto_buscado: 'kit de clutch', encontrado: true)
        job.perform
      end

      expect(ConversationFollowup.last.mensaje).to eq('Ricardo, el kit de clutch sigue apartado, ¿lo buscas hoy?')
    end

    it 'falls back to the general text when the chosen one names a part we do not know' do
      account.update!(settings: account.settings.merge('followups_message_consulta' => 'te guardé {repuesto}'))
      travel_to(midday) do
        quiet_conversation
        job.perform
      end

      expect(ConversationFollowup.last.mensaje).to eq("Ricardo, #{described_class::MESSAGES['generico']}")
    end

    context 'when the conversation is on WhatsApp' do
      let(:whatsapp_channel) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false) }
      let(:whatsapp_inbox) { create(:inbox, channel: whatsapp_channel, account: account) }

      # Same shape as quiet_conversation, on a channel with a 24h window and with the
      # customer's last message placed where the example needs it.
      def whatsapp_conversation(customer_wrote_at:)
        wa_contact_inbox = create(:contact_inbox, contact: contact, inbox: whatsapp_inbox, source_id: '584141234567')
        conversation = create(:conversation, account: account, inbox: whatsapp_inbox, contact: contact,
                                             contact_inbox: wa_contact_inbox, status: :open)
        create(:message, conversation: conversation, account: account, inbox: whatsapp_inbox,
                         message_type: :incoming, created_at: customer_wrote_at)
        create(:message, conversation: conversation, account: account, inbox: whatsapp_inbox,
                         message_type: :outgoing, created_at: 6.hours.ago)
        conversation.update!(waiting_since: nil, last_activity_at: 6.hours.ago)
      end

      it 'cancels rather than writes once the 24h messaging window has closed' do
        travel_to(midday) do
          whatsapp_conversation(customer_wrote_at: 30.hours.ago)
          job.perform
        end

        # Sending anyway leaves a `failed` message in the thread that the customer never got.
        # Conversation#can_reply? cannot catch it: this fork makes it always true.
        expect(ConversationFollowup.last).to have_attributes(status: 'cancelled', cancel_reason: 'fuera_de_ventana')
      end

      it 'still sends while the window is open' do
        travel_to(midday) do
          whatsapp_conversation(customer_wrote_at: 7.hours.ago)
          job.perform
        end

        expect(ConversationFollowup.last.status).to eq('sent')
      end
    end

    it 'offers to warn the customer when the part was never in stock' do
      travel_to(midday) do
        conversation = quiet_conversation
        create(:product_inquiry, conversation: conversation, account: account,
                                 repuesto_buscado: 'bomba de agua', encontrado: false)
        job.perform
      end

      expect(ConversationFollowup.last.mensaje).to include('apenas entre')
    end

    it 'cancels instead of sending when the customer came back during the wait' do
      # Scheduled at 3am, so it waits for the 8am window — that wait is where the customer
      # can come back. At midday it would go out in the same tick with nothing to wait for.
      travel_to(Time.zone.local(2026, 9, 21, 3, 0)) { quiet_conversation && job.perform }

      followup = ConversationFollowup.last
      travel_to(Time.zone.local(2026, 9, 21, 7, 0)) do
        create(:message, conversation: followup.conversation, account: account, message_type: :incoming)
      end
      travel_to(midday) { job.perform }

      expect(followup.reload).to have_attributes(status: 'cancelled', cancel_reason: 'cliente_respondio')
    end

    it 'holds everything outside the send window rather than writing at 3am' do
      travel_to(Time.zone.local(2026, 9, 21, 3, 0)) do
        quiet_conversation
        job.perform
      end

      expect(ConversationFollowup.last.status).to eq('pending')
    end

    it 'leaves a private note for the seller instead of writing to the customer' do
      agent = create(:user, account: account)
      conversation = nil
      travel_to(midday) do
        conversation = quiet_conversation
        conversation.update!(assignee: agent)
        job.perform
      end

      note = conversation.messages.where(private: true).last
      expect(note.content).to include('Seguimiento sugerido')
      expect(conversation.messages.where(private: false, message_type: :outgoing).count).to eq(1)
    end
  end

  describe 'closing' do
    it 'closes as abandonado when the nudge went unanswered' do
      conversation = nil
      travel_to(midday) do
        conversation = quiet_conversation
        job.perform
      end
      travel_to(midday + 49.hours) { job.perform }

      # Not `perdido`: nobody said they were not buying.
      expect(conversation.reload).to have_attributes(status: 'resolved', resolution_type: 'abandonado',
                                                     resolution_reason: nil)
      expect(ConversationFollowup.last.status).to eq('exhausted')
    end

    it 'never closes a conversation a seller owns' do
      agent = create(:user, account: account)
      conversation = nil
      travel_to(midday) do
        conversation = quiet_conversation
        conversation.update!(assignee: agent)
        job.perform
      end
      travel_to(midday + 49.hours) { job.perform }

      # A delivery being coordinated goes quiet because the customer got their parts.
      expect(conversation.reload.status).to eq('open')
      expect(conversation.resolution_type).to be_nil
      expect(ConversationFollowup.last.status).to eq('exhausted')
    end

    it 'records a reply and leaves the conversation open' do
      conversation = nil
      travel_to(midday) do
        conversation = quiet_conversation
        job.perform
      end

      travel_to(midday + 2.hours) do
        create(:message, conversation: conversation, account: account, message_type: :incoming)
        job.perform
      end

      expect(ConversationFollowup.last.status).to eq('replied')
      expect(conversation.reload.status).to eq('open')
    end
  end

  describe 'the switch' do
    it 'does nothing at all for an account that has not switched it on' do
      account.update!(settings: account.settings.merge('followups_enabled' => false))
      travel_to(midday) do
        quiet_conversation
        job.perform
      end

      expect(ConversationFollowup.count).to eq(0)
    end

    it 'holds pending follow-ups while off instead of sending them' do
      travel_to(Time.zone.local(2026, 9, 21, 3, 0)) { quiet_conversation && job.perform }
      account.update!(settings: account.settings.merge('followups_enabled' => false))
      travel_to(midday) { job.perform }

      expect(ConversationFollowup.last.status).to eq('pending')
    end

    it 'drops what went stale while it was off rather than sending it late' do
      travel_to(Time.zone.local(2026, 9, 21, 3, 0)) { quiet_conversation && job.perform }

      # Switched back on a week later: that nudge is about a conversation nobody remembers.
      travel_to(midday + 7.days) { job.perform }

      expect(ConversationFollowup.last).to have_attributes(status: 'cancelled', cancel_reason: 'vencido')
    end
  end
end
