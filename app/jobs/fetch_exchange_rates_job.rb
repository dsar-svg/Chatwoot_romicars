# frozen_string_literal: true

class FetchExchangeRatesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.find_each do |account|
      rate_data = ExchangeRate.fetch_bcv_rate
      next unless rate_data

      today = Date.current
      rate = account.exchange_rates.find_or_initialize_by(effective_date: today)
      rate.assign_attributes(rate_data.merge(effective_date: today))
      rate.save!

      Rails.logger.info "[FetchExchangeRates] Updated rate for account #{account.id}: #{rate_data[:rate]} Bs/USD"
    rescue StandardError => e
      Rails.logger.error "[FetchExchangeRates] Failed for account #{account.id}: #{e.message}"
    end
  end
end
