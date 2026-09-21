# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ConversationFollowup do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  def build_followup(**attrs)
    described_class.new({ conversation: conversation, account: account, etapa: 'cotizado',
                          scheduled_at: Time.current }.merge(attrs))
  end

  describe 'validations' do
    it 'accepts a well formed row' do
      expect(build_followup).to be_valid
    end

    it 'rejects an etapa outside the list' do
      expect(build_followup(etapa: 'inventada')).not_to be_valid
    end

    it 'rejects sin_respuesta as an etapa: silence is an outcome, not a reason to nudge' do
      expect(build_followup(etapa: 'sin_respuesta')).not_to be_valid
    end
  end

  describe 'the double-nudge guard' do
    it 'refuses a second row for the same conversation and attempt' do
      build_followup.save!

      expect { build_followup.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'still allows a later attempt on the same conversation' do
      build_followup.save!

      expect { build_followup(attempt: 2).save! }.not_to raise_error
    end
  end

  describe '.next_send_slot' do
    # Caracas, which is what config.time_zone now resolves to.
    def slot_at(hour)
      travel_to(Time.zone.local(2026, 9, 21, hour, 30)) { described_class.next_send_slot }
    end

    it 'sends right away inside the window' do
      expect(slot_at(14)).to eq(Time.zone.local(2026, 9, 21, 14, 30))
    end

    it 'treats the closing hour as still open' do
      expect(slot_at(20)).to eq(Time.zone.local(2026, 9, 21, 20, 30))
    end

    it 'defers a late-night due time to the next morning instead of waking the customer' do
      expect(slot_at(23)).to eq(Time.zone.local(2026, 9, 22, 8, 0))
    end

    it 'waits for the same morning when it comes due before opening' do
      expect(slot_at(3)).to eq(Time.zone.local(2026, 9, 21, 8, 0))
    end
  end

  describe '#customer_replied?' do
    it 'is false before the follow-up has been sent' do
      expect(build_followup.customer_replied?).to be(false)
    end

    it 'ignores the messages that were already there when it was sent' do
      create(:message, conversation: conversation, account: account, message_type: :incoming,
                       created_at: 2.hours.ago)
      followup = build_followup(status: 'sent', sent_at: 1.hour.ago)

      expect(followup.customer_replied?).to be(false)
    end

    it 'does not count our own follow-up as a reply' do
      followup = build_followup(status: 'sent', sent_at: 1.hour.ago)
      create(:message, conversation: conversation, account: account, message_type: :outgoing,
                       created_at: 30.minutes.ago)

      expect(followup.customer_replied?).to be(false)
    end

    it 'sees an incoming message that arrived after it was sent' do
      followup = build_followup(status: 'sent', sent_at: 1.hour.ago)
      create(:message, conversation: conversation, account: account, message_type: :incoming,
                       created_at: 10.minutes.ago)

      expect(followup.customer_replied?).to be(true)
    end
  end

  describe '.due' do
    it 'picks up pending rows whose time has come and leaves the rest alone' do
      overdue = build_followup(scheduled_at: 10.minutes.ago)
      overdue.save!
      build_followup(attempt: 2, scheduled_at: 10.minutes.from_now).save!
      build_followup(attempt: 3, scheduled_at: 10.minutes.ago, status: 'sent').save!

      expect(described_class.due).to contain_exactly(overdue)
    end
  end
end
