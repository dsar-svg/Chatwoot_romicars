# frozen_string_literal: true

class ImportVehiclePricesFromCsv < ActiveRecord::Migration[7.0]
  def up
    csv_path = Rails.root.join('data', 'vehicle_prices.csv')
    unless File.exist?(csv_path)
      say 'data/vehicle_prices.csv not found, skipping price import'
      return
    end

    account = Account.first
    unless account
      say 'No account found, skipping price import'
      return
    end

    say 'Importing vehicle prices from CSV...'
    file = File.open(csv_path)
    result = VehiclePriceImportService.new(account, file).call

    if result[:success]
      say "Prices: #{result[:created]} created, #{result[:updated]} updated, #{result[:skipped].size} skipped, #{result[:errors].size} errors"
      result[:skipped].each do |s|
        say "  Skipped row #{s[:row]}: '#{s[:description]}' (variant: '#{s[:variant]}')", true
      end
    else
      say "Price import failed: #{result[:error]}"
    end
  ensure
    file&.close
  end

  def down
    VehiclePrice.destroy_all
  end
end
