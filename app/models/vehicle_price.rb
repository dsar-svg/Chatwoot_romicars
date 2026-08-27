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

  # Fuzzy search over the pg_trgm indexes. The ORDER BY used to interpolate the search
  # term straight into SQL through `sanitize_sql_for_like` — a method that does not
  # exist, so the scope raised NoMethodError on every call, and had it existed it escapes
  # LIKE wildcards, not quotes. Both the filter and the ordering are bound now.
  scope :by_search_trgm, lambda { |search, threshold: 0.15|
    next all if search.blank?

    order_sql = sanitize_sql_array(['similarity(description, ?) DESC', search])

    where(
      'similarity(description, :s) > :t OR similarity(COALESCE(synonyms, \'\'), :s) > :t',
      s: search, t: threshold
    ).order(Arel.sql(order_sql))
  }
end
