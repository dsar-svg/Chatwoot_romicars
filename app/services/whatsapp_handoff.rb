# frozen_string_literal: true

# Moves a sale that started on Instagram or Facebook over to WhatsApp.
#
# The shop sells through WhatsApp Status, and a status only reaches people who have the
# shop's number saved and whose number the shop has saved. So the point is not the chat
# itself: it is ending up with the customer's real phone number on the contact.
#
# The bot does not ask for the number. It sends a wa.me link with the message already
# written, ending in a short code. When the customer taps send, WhatsApp delivers a number
# it has verified, and the code tells us which conversation they came from. A typed number
# is the fallback for when they never tap (see .save_phone).
module WhatsappHandoff
  LABEL = 'derivado-whatsapp'
  # No 0/O, 1/I/L: the customer may read it out loud to a seller.
  CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'.chars.freeze
  CODE_PATTERN = /\bRC-([#{CODE_ALPHABET.join}]{5})\b/i

  class NoWhatsappInbox < StandardError; end
  class InvalidPhone < StandardError; end

  module_function

  def start(conversation, repuesto: nil, vehiculo: nil)
    number = whatsapp_number(conversation.account)
    raise NoWhatsappInbox if number.blank?

    attrs = conversation.custom_attributes || {}
    # Same code on a second call: the customer may have the first link open already.
    code = attrs['wa_code'].presence || "RC-#{Array.new(5) { CODE_ALPHABET.sample(random: SecureRandom) }.join}"
    conversation.update!(custom_attributes: attrs.merge(
      'wa_code' => code,
      'wa_enviado_at' => Time.current.iso8601,
      'wa_repuesto' => repuesto.to_s.squish.presence,
      'wa_vehiculo' => vehiculo.to_s.squish.presence
    ).compact)
    conversation.add_labels([LABEL])

    { code: code, link: "https://wa.me/#{number.delete('+')}?text=#{ERB::Util.url_encode(prefilled_text(code, repuesto, vehiculo))}" }
  end

  # The customer wrote on WhatsApp with a code. Join the two contacts and close where they
  # came from, so the lead is counted once — on the conversation where the sale happens.
  def claim(message)
    code = message.content.to_s[CODE_PATTERN, 0]&.upcase
    return if code.blank?

    arrival = message.conversation
    origin = message.account.conversations.where("custom_attributes ->> 'wa_code' = ?", code).where.not(id: arrival.id).first
    return if origin.blank? || origin.custom_attributes['wa_llego_at'].present?

    merge_contacts(arrival.contact, origin.contact)
    close_origin(origin.reload, arrival)
    activity(arrival, arrival_note(origin))
  end

  # `derivado`, not `consulta` nor `ganado`: the sale, if it happens, is recorded on the
  # WhatsApp conversation. Counting this one too would put the same lead in the funnel twice.
  def close_origin(origin, arrival)
    origin.update!(custom_attributes: origin.custom_attributes.merge('wa_llego_at' => Time.current.iso8601,
                                                                     'wa_conversation_id' => arrival.display_id))
    destino = "por WhatsApp en la conversación ##{arrival.display_id}."
    origin.resolve_with_outcome(resolution_type: 'derivado', resolution_notes: "Siguió #{destino}")
    activity(origin, "El cliente siguió #{destino}")
  end

  # The customer typed a number instead of tapping the link. If another contact already has
  # it — they wrote on WhatsApp before — the two become one, since the number is unique per
  # account and saving it again would only fail validation. Returns the surviving contact.
  def save_phone(contact, raw)
    phone = normalize_phone(raw)
    raise InvalidPhone if phone.blank?

    existing = contact.account.contacts.where.not(id: contact.id).find_by(phone_number: phone)
    return merge_contacts(existing, contact) if existing

    contact.update!(phone_number: phone)
    contact
  end

  # Venezuelan numbers the way people type them: 0414-123.45.67, 414 1234567, 58414...
  def normalize_phone(raw)
    text = raw.to_s.strip
    digits = text.gsub(/\D/, '')
    case digits
    when /\A0([24]\d{9})\z/ then "+58#{Regexp.last_match(1)}"
    when /\A[24]\d{9}\z/ then "+58#{digits}"
    when /\A58[24]\d{9}\z/ then "+#{digits}"
    else "+#{digits}" if text.start_with?('+') && digits.length.between?(8, 15)
    end
  end

  def whatsapp_number(account)
    # ponytail: first WhatsApp inbox of the account; pick one explicitly if the shop ever runs two numbers.
    Channel::Whatsapp.where(account_id: account.id).order(:id).pick(:phone_number)
  end

  def prefilled_text(code, repuesto, vehiculo)
    pedido = [repuesto.to_s.squish.presence, vehiculo.to_s.squish.presence&.then { |v| "para mi #{v}" }].compact.join(' ')
    "Hola Romicars, quiero comprar #{pedido.presence || 'un repuesto'}. Código #{code}"
  end

  # The contact that has the WhatsApp number survives: on arrival the bot is already
  # answering with its id, and destroying it would 404 every call it makes on that turn.
  # The name comes from the other one, where the bot asked for it; WhatsApp gives a profile
  # name, often a dot or an emoji.
  def merge_contacts(whatsapp_contact, other_contact)
    return whatsapp_contact if whatsapp_contact.id == other_contact.id

    name = other_contact.name
    ContactMergeAction.new(account: whatsapp_contact.account, base_contact: whatsapp_contact,
                           mergee_contact: other_contact).perform
    whatsapp_contact.reload
    whatsapp_contact.update!(name: name) if name.to_s.match?(/\p{L}{2}/)
    whatsapp_contact
  end

  def arrival_note(origin)
    attrs = origin.custom_attributes
    pedido = [attrs['wa_repuesto'], attrs['wa_vehiculo'] && "para #{attrs['wa_vehiculo']}"].compact.join(' ')
    "Viene de #{origin.inbox.name} (conversación ##{origin.display_id})#{" por #{pedido}" if pedido.present?}. Contactos unidos."
  end

  def activity(conversation, content)
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id,
                                  message_type: :activity, content: content)
  end
end
