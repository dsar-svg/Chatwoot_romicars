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

      recalculate_prices(account, rate_data)

      Rails.logger.info "[FetchExchangeRates] Account #{account.id}: rate=#{rate_data[:rate]}, equiv_13=#{rate_data[:equiv_13]}"
    rescue StandardError => e
      Rails.logger.error "[FetchExchangeRates] Failed for account #{account.id}: #{e.message}"
    end
  end

  private

  def recalculate_prices(account, rate_data)
    equiv_13 = rate_data[:equiv_13]

    account.vehicle_prices.find_each do |price|
      next unless price.divisor.present?

      new_cost_bs = (price.divisor * equiv_13).round(2)
      new_bolivares = (price.divisor * 1.13).round(2)

      price.update_columns(
        cost_bs: new_cost_bs,
        bolivares: new_bolivares
      )
    end
  end
end
