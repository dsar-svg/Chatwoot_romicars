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
    where('description ILIKE :q OR variant ILIKE :q', q: "%#{search}%") if search.present?
  }
end
