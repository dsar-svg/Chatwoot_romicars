# frozen_string_literal: true

namespace :vehicles do
  desc 'Seed vehicle brands, models and prices from CSV'
  task :seed, [:csv_path] => :environment do |_t, args|
    csv_path = args[:csv_path] || Rails.root.join('data', 'vehicle_prices.csv')
    account = Account.first

    unless account
      puts 'ERROR: No account found. Create an account first.'
      next
    end

    puts "Seeding vehicle data for account #{account.id}..."

    brands_data = {
      'DONGFENG' => ['MINI', 'ZNA', 'S30'],
      'HAIMA' => ['HAIMA 7'],
      'ZOTYE' => ['NOMADA'],
      'CHANA' => ['CHANA 1.1'],
      'CHERY' => ['ARAUCA', 'ARAUCA NUEVO S15', 'ORINOCO', 'X1', 'QQ 2018', 'TIGGO 2.0', 'TIUNA X5', 'PANEL H5', 'GRAN TIGGO']
    }

    brands_data.each do |brand_name, model_names|
      brand = account.vehicle_brands.find_or_create_by!(name: brand_name)
      puts "  Brand: #{brand.name} (ID: #{brand.id})"

      model_names.each do |model_name|
        account.vehicle_models.find_or_create_by!(
          vehicle_brand: brand,
          name: model_name
        )
        puts "    Model: #{model_name}"
      end
    end

    rate_data = ExchangeRate.fetch_bcv_rate
    if rate_data
      today = Date.current
      account.exchange_rates.find_or_create_by!(
        effective_date: today
      ).update!(rate_data)
      puts "  Exchange rate: #{rate_data[:rate]} Bs/USD (equiv 13%: #{rate_data[:equiv_13]})"
    else
      puts '  WARNING: could not fetch BCV rate, skipping exchange rate seed'
    end

    if File.exist?(csv_path)
      puts "\nImporting prices from #{csv_path}..."
      result = VehiclePriceImportService.new(account, File.open(csv_path)).call
      if result[:success]
        puts "  Created: #{result[:created]} prices"
        puts "  Updated: #{result[:updated]} prices"
        puts "  Skipped: #{result[:skipped].size} rows (unknown brand/model)"
        result[:skipped].each do |s|
          puts "    Row #{s[:row]}: '#{s[:description]}' (variant: '#{s[:variant]}')"
        end
        puts "  Errors: #{result[:errors].size}" if result[:errors].any?
      else
        puts "  ERROR: #{result[:error]}"
      end
    else
      puts "\nCSV file not found at #{csv_path}. Skipping price import."
      puts '  Run with: rails vehicles:seed[path/to/file.csv]'
    end

    puts "\nDone!"
  end
end
