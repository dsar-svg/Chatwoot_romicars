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
  # IVA applied on top of the BCV rate to obtain `equiv_13`.
  IVA_MULTIPLIER = BigDecimal('1.13')
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  def self.fetch_bcv_rate
    data = JSON.parse(get_bcv_response)

    official = data.find { |d| d['fuente'] == 'oficial' }
    return nil unless official

    rate = official['promedio'].to_d
    return nil unless rate.positive?

    { rate: rate, equiv_13: (rate * IVA_MULTIPLIER).round(2), source: 've.dolarapi.com' }
  rescue StandardError => e
    # Used to swallow every failure silently, which made a stale rate indistinguishable
    # from a broken upstream.
    Rails.logger.error "[ExchangeRate] BCV fetch failed: #{e.class}: #{e.message}"
    nil
  end

  def self.get_bcv_response
    uri = URI(BCV_API_URL)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      response = http.request(Net::HTTP::Get.new(uri))
      raise "unexpected response #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
  private_class_method :get_bcv_response

  # Repricing the whole catalogue used to be a `find_each` + one UPDATE per row, run
  # inline inside the web request. This is a single statement instead.
  #
  # bolivares = divisa * equiv_13 (whole number - the column is an integer)
  # monto_bs  = bolivares * tasa_bcv, rounded to 2 decimals
  def self.recalculate_prices!(account, equiv_13)
    equiv_13 = equiv_13.to_d
    return 0 unless equiv_13.positive?

    tasa_bcv = equiv_13 / IVA_MULTIPLIER

    account.vehicle_prices.where.not(divisa: nil).update_all([
      'bolivares = ROUND(divisa * ?), monto_bs = ROUND(ROUND(divisa * ?) * ?, 2), updated_at = ?',
      equiv_13, equiv_13, tasa_bcv, Time.current
    ])
  end
end
