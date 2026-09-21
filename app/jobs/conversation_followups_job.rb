# frozen_string_literal: true

# Drives the whole life of a follow-up in one tick: schedule what went quiet, send what is
# due, close what never came back.
#
# Three passes rather than three jobs because they share the eligibility rules and each one
# is a handful of rows. One cron entry is also one thing to reason about at 3am.
class ConversationFollowupsJob < ApplicationJob
  queue_as :scheduled_jobs

  # The copy lives here on purpose: this is the part the shop will want to reword, and it
  # should not require touching the logic to do it. `%{repuesto}` is what the customer
  # actually asked for, which is the only reason the message earns a reply — "¿sigues ahí?"
  # earns none.
  MESSAGES = {
    'cotizado' => '%<saludo>s¿seguís interesado en %<repuesto>s? Lo tengo disponible 🔧',
    'sin_stock' => '%<saludo>stodavía no me llega %<repuesto>s. ¿Te aviso apenas entre?',
    'consulta' => '%<saludo>s¿estabas buscando algún repuesto en particular? Te lo reviso 🔧'
  }.freeze

  GENERIC = '%<saludo>s¿seguís necesitando lo que me consultaste? Te lo reviso 🔧'

  ASSISTED_LABEL = 'seguimiento-pendiente'

  def perform
    schedule_new
    send_due
    resolve_sent
  end

  private

  # Mirrors Chatwoot's own `resolvable_not_waiting` scope: `waiting_since IS NULL` means an
  # agent or the bot answered last, so the ball is in the customer's court. With it set, the
  # one who went quiet is us — that is an SLA problem, and nudging the customer for it would
  # be backwards.
  def eligible_conversations
    Conversation
      .where(status: %i[open pending])
      .where(waiting_since: nil)
      .where(last_activity_at: ..ConversationFollowup::SILENCE_BEFORE_FOLLOWUP.ago)
      .where(resolution_type: nil, sale_amount: nil)
      .where.not(id: ConversationFollowup.select(:conversation_id))
      # At least one message from the customer. Without this, an outbound campaign that
      # nobody ever answered would get chased as if it were a warm lead.
      .where(id: Message.where(message_type: :incoming).select(:conversation_id))
      .joins(:contact)
      .where("COALESCE(contacts.custom_attributes->>'followups_opt_out', 'false') <> 'true'")
  end

  def schedule_new
    eligible_conversations.find_each do |conversation|
      ConversationFollowup.create!(
        conversation: conversation,
        account_id: conversation.account_id,
        etapa: etapa_for(conversation),
        mode: conversation.assignee_id.present? ? 'assisted' : 'auto',
        motivo: motivo_for(conversation),
        scheduled_at: ConversationFollowup.next_send_slot
      )
    rescue ActiveRecord::RecordNotUnique
      # Two ticks overlapped. The unique index did its job; nothing to do.
      next
    rescue StandardError => e
      Rails.logger.error "[Followups] schedule failed for conversation #{conversation.id}: #{e.class}: #{e.message}"
    end
  end

  def send_due
    # Outside 8am-8pm nothing goes out. The rows stay pending and the next morning's tick
    # picks them up.
    return unless ConversationFollowup.sendable_now?

    ConversationFollowup.due.find_each do |followup|
      reason = disqualified(followup)
      next followup.cancel!(reason) if reason

      deliver(followup)
    rescue StandardError => e
      Rails.logger.error "[Followups] send failed for followup #{followup.id}: #{e.class}: #{e.message}"
    end
  end

  # Everything that can change during the five hours between scheduling and sending. The
  # customer coming back is the common one, and sending anyway is the failure everybody
  # notices.
  def disqualified(followup)
    conversation = followup.conversation

    return 'cliente_respondio' if conversation.messages
                                              .where(message_type: :incoming)
                                              .where(created_at: followup.created_at..).exists?
    return 'conversacion_cerrada' unless conversation.open? || conversation.pending?
    return 'resultado_ya_declarado' if conversation.resolution_type.present?
    return 'venta_registrada' if conversation.sale_amount.present?

    nil
  end

  def deliver(followup)
    conversation = followup.conversation
    body = compose(conversation, followup.etapa)

    if followup.mode == 'assisted'
      # A seller owns this one. Auto-sending on their behalf is how they find out what was
      # promised only when the customer answers.
      leave_note(conversation, body, followup.motivo)
    else
      conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        content: body
      )
    end

    followup.update!(status: 'sent', sent_at: Time.current, mensaje: body)
  end

  def leave_note(conversation, body, motivo)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      private: true,
      content: "Seguimiento sugerido (#{motivo}):\n\n#{body}"
    )
    conversation.add_labels([ASSISTED_LABEL])
  end

  def resolve_sent
    ConversationFollowup.sent.find_each do |followup|
      next followup.update!(status: 'replied') if followup.customer_replied?
      next unless followup.sent_at <= ConversationFollowup::CLOSE_AFTER.ago

      close_as_silent(followup)
    rescue StandardError => e
      Rails.logger.error "[Followups] resolve failed for followup #{followup.id}: #{e.class}: #{e.message}"
    end
  end

  def close_as_silent(followup)
    conversation = followup.conversation
    saved = conversation.resolve_with_outcome(
      resolution_type: 'perdido',
      resolution_reason: 'sin_respuesta',
      resolution_notes: "Cerrada sin respuesta. Seguimiento enviado el #{followup.sent_at.strftime('%d/%m %H:%M')}."
    )

    # resolve_with_outcome uses `save`, not `save!`. A silent false here would otherwise
    # leave the row marked exhausted over a conversation that is still open.
    return Rails.logger.error("[Followups] could not close conversation #{conversation.id}") unless saved

    followup.update!(status: 'exhausted')
  end

  def etapa_for(conversation)
    inquiry = last_inquiry(conversation)
    return 'consulta' if inquiry.blank?

    inquiry.encontrado? ? 'cotizado' : 'sin_stock'
  end

  def motivo_for(conversation)
    inquiry = last_inquiry(conversation)
    return 'Consultó y no volvió a escribir' if inquiry.blank?

    prefix = inquiry.encontrado? ? 'Cotizado y sin respuesta' : 'Sin stock y sin respuesta'
    [prefix, inquiry.repuesto_buscado.presence].compact.join(': ')
  end

  def last_inquiry(conversation)
    @last_inquiry ||= {}
    @last_inquiry[conversation.id] ||= ProductInquiry.where(conversation_id: conversation.id).order(:created_at).last
  end

  def compose(conversation, etapa)
    repuesto = last_inquiry(conversation)&.repuesto_buscado.to_s.squish
    template = MESSAGES.fetch(etapa, GENERIC)
    # Naming the part is what makes the message worth answering. Without one, fall back to
    # the vague version rather than sending "¿seguís interesado en ?".
    template = GENERIC if repuesto.blank? && template.include?('%<repuesto>s')

    format(template, saludo: saludo_for(conversation), repuesto: repuesto)
  end

  def saludo_for(conversation)
    name = conversation.contact&.name.to_s.strip
    name.present? ? "#{name}, " : ''
  end
end
