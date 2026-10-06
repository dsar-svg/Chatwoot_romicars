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

  BCV_URL = 'https://www.bcv.org.ve/'
  FALLBACK_API_URL = 'https://ve.dolarapi.com/v1/dolares'
  # What the shop adds on top of the BCV rate when the customer pays in bolivars. Each account
  # sets its own (Account#price_markup_percent); this is what it was before it could be set.
  DEFAULT_MARKUP_PERCENT = BigDecimal('13')
  # A new rate further than this from the last one is a broken page, not a devaluation: the
  # whole catalogue is repriced from it and the bot quotes the result.
  MAX_JUMP = BigDecimal('0.25')
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  # { rate:, effective_date:, source: } or nil. The BCV's own page first: the third-party API
  # that used to be the only source keeps the rate in force today, while the BCV has already
  # published the next one, so the dashboard read behind the official page every afternoon.
  def self.fetch_bcv_rate
    [:fetch_from_bcv, :fetch_from_fallback_api].each do |source|
      data = send(source)
      return data if data && plausible?(data[:rate])
    rescue StandardError => e
      # Used to swallow every failure silently, which made a stale rate indistinguishable
      # from a broken upstream.
      Rails.logger.error "[ExchangeRate] #{source} failed: #{e.class}: #{e.message}"
    end
    nil
  end

  def self.equiv_for(rate, markup_percent)
    (rate.to_d * (1 + (markup_percent.to_d / 100))).round(2)
  end

  # Repricing the whole catalogue used to be a `find_each` + one UPDATE per row, run
  # inline inside the web request. This is a single statement instead.
  #
  # monto_bs  = divisa * equiv_13, rounded to 2 decimals
  # bolivares = monto_bs / tasa_bcv (whole number - the column is an integer)
  def self.recalculate_prices!(account, exchange_rate)
    equiv = exchange_rate&.equiv_13.to_d
    tasa_bcv = exchange_rate&.rate.to_d
    return 0 unless equiv.positive? && tasa_bcv.positive?

    account.vehicle_prices.where.not(divisa: nil).update_all([
      'monto_bs = ROUND(divisa * ?, 2), bolivares = ROUND(ROUND(divisa * ?, 2) / ?), updated_at = ?',
      equiv, equiv, tasa_bcv, Time.current
    ])
  end

  # Stores the fetched rate under its own date, with this account's markup, and reprices.
  def self.apply!(account, rate_data)
    record = account.exchange_rates.find_or_initialize_by(effective_date: rate_data[:effective_date])
    record.assign_attributes(rate: rate_data[:rate], source: rate_data[:source],
                             equiv_13: equiv_for(rate_data[:rate], account.price_markup_percent))
    record.save!
    recalculate_prices!(account, account.exchange_rates.ordered.first)
    record
  end

  def self.fetch_from_bcv
    html = http_get(BCV_URL).force_encoding(Encoding::UTF_8).scrub
    # <div id="dolar"> ... <strong> 873,86700000 </strong>
    amount = html[%r{id="dolar".*?<strong[^>]*>\s*([\d.,]+)\s*</strong>}m, 1]
    return nil if amount.blank?

    # Fecha Valor: <span ... content="2026-10-07T00:00:00-04:00">
    date = html[/Fecha Valor:.*?content="(\d{4}-\d{2}-\d{2})/m, 1]
    { rate: amount.delete('.').tr(',', '.').to_d.round(2), effective_date: date ? Date.parse(date) : Date.current, source: 'bcv.org.ve' }
  end
  private_class_method :fetch_from_bcv

  def self.fetch_from_fallback_api
    official = JSON.parse(http_get(FALLBACK_API_URL)).find { |d| d['fuente'] == 'oficial' }
    return nil unless official

    { rate: official['promedio'].to_d.round(2), effective_date: Date.current, source: 've.dolarapi.com' }
  end
  private_class_method :fetch_from_fallback_api

  def self.plausible?(rate)
    return false unless rate&.positive?

    last = where(effective_date: 10.days.ago..).order(effective_date: :desc).pick(:rate)
    last.blank? || ((rate - last).abs / last) <= MAX_JUMP
  end
  private_class_method :plausible?

  def self.http_get(url)
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Get.new(uri)
      # The BCV site answers 403 to clients without a browser-like agent.
      request['User-Agent'] = 'Mozilla/5.0 (compatible; RomiCars/1.0)'
      response = http.request(request)
      raise "unexpected response #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
  private_class_method :http_get
end
