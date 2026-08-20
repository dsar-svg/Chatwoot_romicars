# frozen_string_literal: true

class BotLog < ApplicationRecord
  belongs_to :account
  belongs_to :conversation
  belongs_to :contact, optional: true

  validates :tipo_evento, presence: true, inclusion: {
    in: %w[turno_ok agente_fallo redis_fallo vehiculo_invalido cierre_sin_confirmar intencion_compra_sin_traspaso]
  }
  validates :severidad, presence: true, inclusion: { in: %w[info warning error] }

  scope :by_tipo, ->(tipo) { where(tipo_evento: tipo) if tipo.present? }
  scope :by_severidad, ->(sev) { where(severidad: sev) if sev.present? }
  scope :recent, ->(days = 30) { where('created_at >= ?', days.days.ago) }
  scope :ordered, -> { order(created_at: :desc) }

  TIPO_EVENTOS = %w[turno_ok agente_fallo redis_fallo vehiculo_invalido cierre_sin_confirmar intencion_compra_sin_traspaso].freeze
  SEVERIDADES = %w[info warning error].freeze
end
