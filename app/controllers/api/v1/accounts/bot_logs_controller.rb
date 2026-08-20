# frozen_string_literal: true

class Api::V1::Accounts::BotLogsController < Api::V1::Accounts::BaseController
  before_action :fetch_log, only: [:show]

  def index
    @logs = Current.account.bot_logs
                   .by_tipo(params[:tipo_evento])
                   .by_severidad(params[:severidad])
                   .recent(params[:days]&.to_i || 30)
                   .ordered

    render json: {
      payload: @logs.limit(200).map { |log| serialize_log(log) },
      meta: {
        total: @logs.count,
        by_tipo: Current.account.bot_logs
                         .recent(params[:days]&.to_i || 30)
                         .group(:tipo_evento).count,
        by_severidad: Current.account.bot_logs
                              .recent(params[:days]&.to_i || 30)
                              .group(:severidad).count
      }
    }
  end

  def show
    render json: { payload: serialize_log(@log) }
  end

  private

  def fetch_log
    @log = Current.account.bot_logs.find(params[:id])
  end

  def serialize_log(log)
    {
      id: log.id,
      tipo_evento: log.tipo_evento,
      severidad: log.severidad,
      detalle: log.detalle,
      accion_intentada: log.accion_intentada,
      contexto: log.contexto,
      conversation_id: log.conversation_id,
      contact_id: log.contact_id,
      created_at: log.created_at,
      contact_name: log.contact.try(:name),
      conversation_display_id: log.conversation.try(:display_id)
    }
  end
end
