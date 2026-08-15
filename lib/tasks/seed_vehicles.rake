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

    # Create brands
    brands_data = {
      'DONGFENG' => %w[MINI ZNA S30],
      'HAIMA' => ['HAIMA 7'],
      'ZOTYE' => ['NOMADA'],
      'CHANA' => ['CHANA 1.1'],
      'CHERY' => %w[ARAUCA ARAUCA_NUEVO_S15 ORINOCO X1 TIGGO_2.0 TIUNA_X5 PANEL_H5 GRAN_TIGGO]
    }

    brands = {}
    brands_data.each do |brand_name, model_names|
      brand = account.vehicle_brands.find_or_create_by!(name: brand_name)
      brands[brand_name] = brand
      puts "  Brand: #{brand.name} (ID: #{brand.id})"

      model_names.each do |model_name|
        display_name = model_name.gsub('_', ' ')
        account.vehicle_models.find_or_create_by!(
          vehicle_brand: brand,
          name: display_name
        )
        puts "    Model: #{display_name}"
      end
    end

    # Create default exchange rate
    rate_data = ExchangeRate.fetch_bcv_rate
    if rate_data
      today = Date.current
      account.exchange_rates.find_or_create_by!(
        effective_date: today
      ).update!(rate_data)
      puts "  Exchange rate: #{rate_data[:rate]} Bs/USD"
    end

    # Import prices from CSV
    if File.exist?(csv_path)
      puts "\nImporting prices from #{csv_path}..."
      result = VehiclePriceImportService.new(account, File.open(csv_path)).call
      if result[:success]
        puts "  Created: #{result[:created]} prices"
        puts "  Updated: #{result[:updated]} prices"
        puts "  Total: #{result[:total]} rows"
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
