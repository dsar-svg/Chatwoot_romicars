# frozen_string_literal: true

class VehiclePrice < ApplicationRecord
  belongs_to :account
  belongs_to :vehicle_brand
  belongs_to :vehicle_model, optional: true

  validates :description, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:description) }
  scope :by_brand, ->(brand_id) { where(vehicle_brand_id: brand_id) if brand_id.present? }
  scope :by_model, ->(model_id) { where(vehicle_model_id: model_id) if model_id.present? }

  scope :by_search, lambda { |search|
    return all unless search.present?

    query = "%#{sanitize_sql_like(search)}%"
    where(
      'description ILIKE :q OR variant ILIKE :q OR synonyms ILIKE :q',
      q: query
    )
  }

  scope :by_search_trgm, lambda { |search, threshold: 0.15|
    return all unless search.present?

    where(
      'similarity(description, :s) > :t OR similarity(synonyms, :s) > :t',
      s: search, t: threshold
    ).order(Arel.sql("similarity(description, '#{sanitize_sql_for_like(search)}') DESC"))
  }
end
