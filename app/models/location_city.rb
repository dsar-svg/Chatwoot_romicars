# frozen_string_literal: true

class LocationCity < ApplicationRecord
  belongs_to :location_state
  belongs_to :account

  validates :name, presence: true
  validates :name, uniqueness: { scope: :location_state_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :by_state, ->(state_id) { where(location_state_id: state_id) if state_id.present? }
end
