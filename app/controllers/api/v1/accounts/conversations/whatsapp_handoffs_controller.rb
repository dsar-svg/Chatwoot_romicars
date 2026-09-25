# The bot's two ways to move a sale to WhatsApp: a wa.me link (create), or the number the
# customer typed when they would rather be written to (update).
class Api::V1::Accounts::Conversations::WhatsappHandoffsController < Api::V1::Accounts::Conversations::BaseController
  def create
    render json: WhatsappHandoff.start(@conversation, repuesto: params[:repuesto], vehiculo: params[:vehiculo])
  rescue WhatsappHandoff::NoWhatsappInbox
    render json: { error: 'La cuenta no tiene una bandeja de WhatsApp conectada' }, status: :unprocessable_entity
  end

  def update
    contact = WhatsappHandoff.save_phone(@conversation.contact, params[:telefono])
    render json: { contact_id: contact.id, phone_number: contact.phone_number }
  rescue WhatsappHandoff::InvalidPhone
    # Worded for the bot, which relays it: it should ask again, not apologise for a system error.
    render json: { error: 'Número incompleto o inválido. Pídele el número de nuevo con el código de área, ej. 0414-1234567' },
           status: :unprocessable_entity
  end
end
