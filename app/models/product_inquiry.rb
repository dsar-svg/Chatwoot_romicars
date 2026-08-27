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
  scope :with_repuesto, -> { where.not(repuesto_buscado: [nil, '']) }
  scope :with_canal, -> { where.not(canal: [nil, '']) }

  # These grouped aggregates all ordered by `count_id`, a column that does not exist:
  # `group(...).count` aliases its aggregate as `count_all`, and Rails 7 rejects raw
  # non-attribute order arguments, so every one of them raised instead of returning rows.
  COUNT_DESC = Arel.sql('COUNT(*) DESC')

  def self.top_repuestos(limit = 20)
    with_repuesto
      .group(:repuesto_buscado)
      .order(COUNT_DESC)
      .limit(limit)
      .count
  end

  def self.by_canal_stats
    with_canal
      .group(:canal)
      .order(COUNT_DESC)
      .count
  end

  def self.top_repuestos_by_canal
    with_canal
      .with_repuesto
      .group(:canal, :repuesto_buscado)
      .order(Arel.sql('canal ASC, COUNT(*) DESC'))
      .count
  end

  def self.not_found_repuestos(limit = 20)
    not_found
      .with_repuesto
      .group(:repuesto_buscado, :marca_buscada, :modelo_buscado)
      .order(COUNT_DESC)
      .limit(limit)
      .count
  end
end
