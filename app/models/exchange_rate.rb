# frozen_string_literal: true

require 'net/http'
require 'json'

class ExchangeRate < ApplicationRecord
  belongs_to :account

  validates :rate, presence: true
  validates :effective_date, presence: true
  validates :effective_date, uniqueness: { scope: :account_id }

  scope :ordered, -> { order(effective_date: :desc) }
  scope :latest, -> { order(effective_date: :desc).first }

  BCV_API_URL = 'https://ve.dolarapi.com/v1/dolares'

  def self.fetch_bcv_rate
    uri = URI(BCV_API_URL)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    official = data.find { |d| d['fuente'] == 'oficial' }
    return nil unless official

    rate = official['promedio'].to_d
    equiv_13 = (rate * 1.13).round(2)
    { rate: rate, equiv_13: equiv_13, source: 've.dolarapi.com' }
  rescue StandardError
    nil
  end
end
