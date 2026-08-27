# frozen_string_literal: true

class FetchExchangeRatesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Fetched once. This used to sit inside the loop, hitting ve.dolarapi.com once per
    # account for a value that is identical for all of them.
    rate_data = ExchangeRate.fetch_bcv_rate
    return Rails.logger.error('[FetchExchangeRates] Skipped: could not fetch BCV rate') if rate_data.nil?

    today = Date.current

    Account.find_each do |account|
      rate = account.exchange_rates.find_or_initialize_by(effective_date: today)
      rate.assign_attributes(rate_data.merge(effective_date: today))
      rate.save!

      updated = ExchangeRate.recalculate_prices!(account, rate_data[:equiv_13])

      Rails.logger.info "[FetchExchangeRates] Account #{account.id}: rate=#{rate_data[:rate]}, " \
                        "equiv_13=#{rate_data[:equiv_13]}, prices_updated=#{updated}"
    rescue StandardError => e
      Rails.logger.error "[FetchExchangeRates] Failed for account #{account.id}: #{e.message}"
    end
  end
end
