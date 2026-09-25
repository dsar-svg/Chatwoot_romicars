# frozen_string_literal: true

# Drives the whole life of a follow-up in one tick: schedule what went quiet, send what is
# due, close what never came back.
#
# Three passes rather than three jobs because they share the eligibility rules and each one
# is a handful of rows. One cron entry is also one thing to reason about at 3am.
class ConversationFollowupsJob < ApplicationJob
  queue_as :scheduled_jobs

  # Defaults. Each one can be rewritten per account from Settings > Conversation workflow,
  # and a blank field falls back to these. `{repuesto}` is what the customer actually asked
  # for, which is the only reason the message earns a reply — "¿sigues ahí?" earns none. The
  # customer's name is prefixed on its own ("Ricardo, ...") so an edited text never ends up
  # saying "Hola ," to someone we have no name for.
  #
  # None of these may claim the part is in stock. `vehicle_prices` carries a price, a
  # variant and a currency, but no quantity: a hit on `encontrado` means the part is in the
  # price list, not that a unit is on the shelf. Offering to hold one, or to warn the
  # customer when it arrives, would be inventing. Only `sin_stock` speaks about
  # availability, and it can, because `encontrado: false` is a recorded fact.
  MESSAGES = {
    'cotizado' => '¿sigues interesado en {repuesto}? Te confirmo disponibilidad 🔧',
    'sin_stock' => 'todavía no me llega {repuesto}. ¿Te aviso apenas entre?',
    'consulta' => '¿estabas buscando algún repuesto en particular? Te lo reviso 🔧',
    # Sent the wa.me link and never showed up on WhatsApp. Asking for the number is the
    # fallback: the bot saves it and a seller writes from the phone.
    'derivado' => '¿pudiste escribirnos por WhatsApp? Si prefieres, déjame tu número y te escribimos nosotros 📲',
    # Used whenever the chosen text names the part and we do not know which part it was.
    'generico' => '¿sigues necesitando lo que me consultaste? Te lo reviso 🔧'
  }.freeze

  PART_TOKEN = '{repuesto}'

  # Hours of silence before the nudge are set per account, capped here. The job also holds
  # anything that comes due at night until 8am — up to 12 more hours — and past 24 hours
  # since the customer's last message WhatsApp and Instagram refuse anything that is not an
  # approved template. 12 + 12 is the most that still lands inside the window.
  MAX_SILENCE_HOURS = 12

  # Channels where Meta refuses a free-form message 24 hours after the customer's last one.
  # Checked here rather than through Conversation#can_reply?: for an automated message the
  # rule is 24 hours even where Messenger and Instagram give a human agent seven days.
  WINDOWED_CHANNELS = %w[Channel::Whatsapp Channel::FacebookPage Channel::Instagram].freeze
  MESSAGING_WINDOW = 24.hours

  ASSISTED_LABEL = 'seguimiento-pendiente'

  # A pending follow-up older than this is not sent. Rows only wait this long when the job
  # was switched off, and switching it back on must not fire a week of stale nudges at once.
  STALE_AFTER = 1.day

  # Off unless an admin switches it on for the account, from Settings > Conversation
  # workflow. This job writes to real customers on its own every fifteen minutes, so it
  # stays dormant until someone decides otherwise — and the switch doubles as the fastest
  # way to stop it, faster than any redeploy.
  #
  # It used to be the FOLLOWUPS_ENABLED environment variable. One switch, not two: with
  # both, someone flips the one they can see and nothing happens.
  def perform
    accounts = Account.where("settings ->> 'followups_enabled' = 'true'")
    return Rails.logger.info('[Followups] off for every account') unless accounts.exists?

    # One account at a time: the silence and the texts are per account.
    accounts.find_each do |account|
      schedule_new(account)
      send_due(account)
      resolve_sent(account)
    end
  end

  private

  # Mirrors Chatwoot's own `resolvable_not_waiting` scope: `waiting_since IS NULL` means an
  # agent or the bot answered last, so the ball is in the customer's court. With it set, the
  # one who went quiet is us — that is an SLA problem, and nudging the customer for it would
  # be backwards.
  def eligible_conversations(account)
    Conversation
      .where(account_id: account.id)
      .where(status: %i[open pending])
      .where(waiting_since: nil)
      .where(last_activity_at: ..silence_for(account).ago)
      .where(resolution_type: nil, sale_amount: nil)
      .where.not(id: ConversationFollowup.select(:conversation_id))
      # At least one message from the customer. Without this, an outbound campaign that
      # nobody ever answered would get chased as if it were a warm lead.
      .where(id: Message.where(message_type: :incoming).select(:conversation_id))
      # Suppliers and the delivery rider (Conversation::NON_LEAD_LABELS, on the thread or on
      # the contact) have no funnel to chase: the rider going quiet after "estoy afuera" means
      # the parts arrived, not that a sale was lost.
      .leads
      .joins(:contact)
      .where("COALESCE(contacts.custom_attributes->>'followups_opt_out', 'false') <> 'true'")
  end

  def schedule_new(account)
    eligible_conversations(account).find_each do |conversation|
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

  def send_due(account)
    # Outside 8am-8pm nothing goes out. The rows stay pending and the next morning's tick
    # picks them up.
    return unless ConversationFollowup.sendable_now?

    ConversationFollowup.due.where(account_id: account.id).find_each do |followup|
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
    return 'vencido' if followup.scheduled_at < STALE_AFTER.ago
    # Past 24 hours since the customer's last message, anything but a template is refused.
    # Chatwoot would still create the message, as `failed` — so the seller sees a reminder in
    # the thread that never reached the customer. A private note has no window.
    return 'fuera_de_ventana' if followup.mode == 'auto' && outside_messaging_window?(conversation)

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
        sender: sender_for(conversation),
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
      sender: sender_for(conversation),
      private: true,
      content: "Seguimiento sugerido (#{motivo}):\n\n#{body}"
    )
    conversation.add_labels([ASSISTED_LABEL])
  end

  # A message with no sender is labelled with a generic "Bot" in the dashboard, right next
  # to the named bot the customer has been talking to all along. The inbox's own agent bot
  # is the name already on every other outgoing message in that thread.
  def sender_for(conversation)
    conversation.inbox.agent_bot
  end

  def resolve_sent(account)
    ConversationFollowup.sent.where(account_id: account.id).find_each do |followup|
      next followup.update!(status: 'replied') if followup.customer_replied?
      next unless followup.sent_at <= ConversationFollowup::CLOSE_AFTER.ago

      # A seller owns an assisted follow-up — all we did was leave them a note. Closing on
      # their behalf is how a delivery in progress gets filed as a lost sale two days after
      # the customer stopped writing because they received their parts. The row goes
      # terminal so the job stops looking at it; the conversation is theirs to close.
      next followup.update!(status: 'exhausted') if followup.mode == 'assisted'

      close_as_silent(followup)
    rescue StandardError => e
      Rails.logger.error "[Followups] resolve failed for followup #{followup.id}: #{e.class}: #{e.message}"
    end
  end

  def close_as_silent(followup)
    conversation = followup.conversation
    # `abandonado`, not `perdido`: nobody said they were not buying. No reason either —
    # `resolve_with_outcome` only keeps one for a declared loss, and here the type already
    # says everything we know.
    saved = conversation.resolve_with_outcome(
      resolution_type: 'abandonado',
      resolution_notes: "Cerrada sin respuesta. Seguimiento enviado el #{followup.sent_at.strftime('%d/%m %H:%M')}."
    )

    # resolve_with_outcome uses `save`, not `save!`. A silent false here would otherwise
    # leave the row marked exhausted over a conversation that is still open.
    return Rails.logger.error("[Followups] could not close conversation #{conversation.id}") unless saved

    followup.update!(status: 'exhausted')
  end

  def etapa_for(conversation)
    return 'derivado' if conversation.custom_attributes&.dig('wa_code').present?

    inquiry = last_inquiry(conversation)
    return 'consulta' if inquiry.blank?

    inquiry.encontrado? ? 'cotizado' : 'sin_stock'
  end

  def motivo_for(conversation)
    return 'Se le mandó el link de WhatsApp y no escribió' if conversation.custom_attributes&.dig('wa_code').present?

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
    settings = conversation.account.settings || {}
    template = message_for(settings, etapa)
    # Naming the part is what makes the message worth answering. Without one, fall back to
    # the general version rather than sending "¿sigues interesado en ?" — and if the shop
    # rewrote the general one to name the part too, to the built-in default.
    template = message_for(settings, 'generico') if repuesto.blank? && template.include?(PART_TOKEN)
    template = MESSAGES['generico'] if repuesto.blank? && template.include?(PART_TOKEN)

    "#{saludo_for(conversation)}#{template.gsub(PART_TOKEN, repuesto)}"
  end

  def outside_messaging_window?(conversation)
    return false unless WINDOWED_CHANNELS.include?(conversation.inbox.channel_type)

    last_incoming = conversation.messages.where(message_type: :incoming).maximum(:created_at)
    last_incoming.nil? || last_incoming < MESSAGING_WINDOW.ago
  end

  def message_for(settings, etapa)
    settings["followups_message_#{etapa}"].to_s.strip.presence || MESSAGES.fetch(etapa, MESSAGES['generico'])
  end

  # Blank or zero means the default; anything above the cap is held to it, because the
  # settings screen is not the only way to write this value.
  def silence_for(account)
    hours = account.settings&.dig('followups_silence_hours').to_i
    return ConversationFollowup::SILENCE_BEFORE_FOLLOWUP if hours <= 0

    [hours, MAX_SILENCE_HOURS].min.hours
  end

  def saludo_for(conversation)
    name = conversation.contact&.name.to_s.strip
    name.present? ? "#{name}, " : ''
  end
end
