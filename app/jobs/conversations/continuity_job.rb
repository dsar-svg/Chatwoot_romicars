# A customer who asks today and buys the day after opens a second conversation. Each one
# looked like its own lead, so the first closed as "sin respuesta" and the second as a sale
# out of nowhere. This ties the second to the first: the seller sees what was already
# quoted, and the report can count the ones that came back.
class Conversations::ContinuityJob < ApplicationJob
  queue_as :low

  WINDOW = 14.days
  OUTCOMES = {
    'ganado' => 'venta', 'perdido' => 'perdida', 'consulta' => 'consulta resuelta',
    'abandonado' => 'sin respuesta', 'derivado' => 'pasó a WhatsApp'
  }.freeze

  def perform(conversation)
    previous = conversation.contact.conversations
                           .where.not(id: conversation.id)
                           .where(created_at: ...conversation.created_at, last_activity_at: WINDOW.ago..)
                           # A wa.me handoff already links the two threads (WhatsappHandoff); counting
                           # it here too would report every one of them as a customer who came back.
                           .where('conversations.resolution_type IS DISTINCT FROM ?', 'derivado')
                           .order(last_activity_at: :desc)
                           .first
    return if previous.blank?

    conversation.update!(custom_attributes: (conversation.custom_attributes || {}).merge('continua_de' => previous.display_id))
    conversation.messages.create!(account_id: conversation.account_id, inbox_id: conversation.inbox_id,
                                  message_type: :activity, content: summary(previous))
  end

  private

  def summary(previous)
    repuesto = ProductInquiry.where(conversation_id: previous.id).order(:created_at).last&.repuesto_buscado.presence
    [
      "Continúa la conversación ##{previous.display_id} (#{previous.inbox.name}, #{previous.last_activity_at.strftime('%d/%m')})",
      repuesto && "pidió #{repuesto}",
      OUTCOMES[previous.resolution_type] && "cerrada: #{OUTCOMES[previous.resolution_type]}"
    ].compact.join(' · ')
  end
end
