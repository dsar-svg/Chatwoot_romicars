# frozen_string_literal: true

class FetchExchangeRatesJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    # Fetched once: the rate is the same for every account, only the markup differs.
    rate_data = ExchangeRate.fetch_bcv_rate
    return Rails.logger.error('[FetchExchangeRates] Skipped: could not fetch BCV rate') if rate_data.nil?

    Account.find_each do |account|
      rate = ExchangeRate.apply!(account, rate_data)

      Rails.logger.info "[FetchExchangeRates] Account #{account.id}: rate=#{rate.rate}, " \
                        "equiv=#{rate.equiv_13}, date=#{rate.effective_date}, source=#{rate.source}"
    rescue StandardError => e
      Rails.logger.error "[FetchExchangeRates] Failed for account #{account.id}: #{e.message}"
    end
  end
end
