# frozen_string_literal: true

# One scheduled nudge for a conversation the customer went quiet on.
#
# The lifecycle is deliberately small:
#
#   pending --(5h of silence)--> sent --(48h more silence)--> exhausted
#      |                           |
#      +--(customer came back,     +--(customer answered)--> replied
#          or a human took over)
#          --> cancelled
#
# `exhausted` means the nudge is spent. For an `auto` follow-up it also closes the
# conversation, always as `abandonado` — silence is the absence of an outcome, not a loss,
# and every real loss reason is declared by the customer and written by the bot at close
# time. For an `assisted` one it closes nothing: a seller owns that thread.
class ConversationFollowup < ApplicationRecord
  # What we are nudging about. Each one gets a different message, because "¿sigues ahí?"
  # converts nothing and the reason to reply is already in the data.
  ETAPAS = %w[cotizado sin_stock consulta derivado].freeze
  STATUSES = %w[pending sent cancelled replied exhausted].freeze

  # `auto` sends by itself. `assisted` only leaves a private note and a label, because a
  # seller who owns the conversation should not find out what was promised on their behalf
  # when the customer answers.
  MODES = %w[auto assisted].freeze

  SILENCE_BEFORE_FOLLOWUP = 5.hours
  CLOSE_AFTER = 48.hours

  # Never write to someone at 3am: it earns a block, and a blocked number costs far more
  # than a late nudge. A due row outside the window waits for the next morning.
  SEND_WINDOW = (8..20).freeze

  belongs_to :conversation
  belongs_to :account

  validates :etapa, inclusion: { in: ETAPAS }
  validates :status, inclusion: { in: STATUSES }
  validates :mode, inclusion: { in: MODES }
  validates :scheduled_at, presence: true

  scope :pending, -> { where(status: 'pending') }
  scope :due, -> { pending.where(scheduled_at: ..Time.current) }
  scope :sent, -> { where(status: 'sent') }
  scope :awaiting_reply, ->(window = CLOSE_AFTER) { sent.where(sent_at: ..window.ago) }
  scope :by_etapa, ->(etapa) { where(etapa: etapa) if etapa.present? }

  def self.sendable_now?(now = Time.current)
    SEND_WINDOW.cover?(now.hour)
  end

  # The next moment inside the window, so a follow-up that comes due at 11pm goes out at 8am
  # rather than being skipped or waking the customer.
  def self.next_send_slot(from = Time.current)
    return from if sendable_now?(from)

    from.hour < SEND_WINDOW.first ? from.change(hour: SEND_WINDOW.first) : from.tomorrow.change(hour: SEND_WINDOW.first)
  end

  def cancel!(reason)
    update!(status: 'cancelled', cancelled_at: Time.current, cancel_reason: reason)
  end

  # Keyed off sent_at rather than the conversation's last activity: the follow-up is itself
  # an outgoing message, so last_activity_at always looks fresh and the conversation would
  # never close.
  def customer_replied?
    return false if sent_at.blank?

    conversation.messages.where(message_type: :incoming).where(created_at: sent_at..).exists?
  end
end
