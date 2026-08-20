# frozen_string_literal: true

class ProductInquiry < ApplicationRecord
  belongs_to :conversation
  belongs_to :account

  scope :by_canal, ->(canal) { where(canal: canal) if canal.present? }
  scope :by_marca, ->(marca) { where(marca_buscada: marca) if marca.present? }
  scope :by_date_range, ->(start_date, end_date) {
    where(created_at: start_date..end_date) if start_date.present? && end_date.present?
  }
  scope :not_found, -> { where(encontrado: false) }
  scope :found, -> { where(encontrado: true) }

  def self.top_repuestos(limit = 20)
    group(:repuesto_buscado)
      .order('count_id DESC')
      .limit(limit)
      .count
  end

  def self.by_canal_stats
    group(:canal)
      .order('count_id DESC')
      .count
  end

  def self.top_repuestos_by_canal
    group(:canal, :repuesto_buscado)
      .order('canal, count_id DESC')
      .count
  end

  def self.not_found_repuestos(limit = 20)
    not_found
      .group(:repuesto_buscado, :marca_buscada, :modelo_buscado)
      .order('count_id DESC')
      .limit(limit)
      .count
  end
end
