# frozen_string_literal: true

class LocationState < ApplicationRecord
  belongs_to :account
  has_many :location_cities, dependent: :destroy_async

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
end
