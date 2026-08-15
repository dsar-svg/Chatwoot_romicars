# frozen_string_literal: true

class VehicleBrand < ApplicationRecord
  belongs_to :account
  has_many :vehicle_models, dependent: :destroy_async
  has_many :vehicle_prices, dependent: :destroy_async

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
