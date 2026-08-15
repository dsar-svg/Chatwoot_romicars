# frozen_string_literal: true

class VehicleModel < ApplicationRecord
  belongs_to :vehicle_brand
  belongs_to :account
  has_many :vehicle_prices, dependent: :destroy_async

  validates :name, presence: true
  validates :name, uniqueness: { scope: :vehicle_brand_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :by_brand, ->(brand_id) { where(vehicle_brand_id: brand_id) if brand_id.present? }
end
