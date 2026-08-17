# frozen_string_literal: true

namespace :vehicles do
  desc 'Import synonyms from CSV into vehicle_prices'
  task import_synonyms: :environment do
    csv_path = Rails.root.join('data', 'sinonimos.csv')
    unless File.exist?(csv_path)
      puts "ERROR: #{csv_path} not found"
      next
    end

    account = Account.first
    unless account
      puts 'ERROR: No account found'
      next
    end

    content = File.binread(csv_path)
    utf8 = content.dup.force_encoding('UTF-8')
    utf8 = content.dup.force_encoding('Windows-1252').encode('UTF-8', invalid: :replace, undef: :replace) unless utf8.valid_encoding?

    rows = CSV.parse(utf8, headers: true)
    updated = 0
    skipped = 0
    errors = []

    rows.each_with_index do |row, i|
      description = row['Descripcion']&.to_s&.strip
      brand_name = row['Marca']&.to_s&.strip
      variant_raw = row['Variante']&.to_s&.strip
      synonyms = row['Sinonimo']&.to_s&.strip

      next if description.blank? || synonyms.blank?

      # Find the brand
      brand = account.vehicle_brands.find_by(name: brand_name)
      unless brand
        skipped += 1
        next
      end

      # Find the price by description + brand (and variant if present)
      price = account.vehicle_prices
                      .where(description: description, vehicle_brand_id: brand.id)

      if variant_raw.present?
        variant_normalized = variant_raw.upcase.gsub(',', '.').squeeze(' ').strip
        price = price.where(variant: variant_normalized)
      end

      price = price.first

      unless price
        skipped += 1
        next
      end

      price.update!(synonyms: synonyms)
      updated += 1
    rescue StandardError => e
      errors << { row: i + 2, error: e.message }
    end

    puts "Synonyms imported: #{updated} updated, #{skipped} skipped, #{errors.size} errors"
    errors.first(5).each { |e| puts "  Row #{e[:row]}: #{e[:error]}" }
    puts 'Done!'
  end
end
