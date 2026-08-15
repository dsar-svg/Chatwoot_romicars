# frozen_string_literal: true

class VehiclePriceImportService
  def initialize(account, file)
    @account = account
    @file = file
  end

  def call
    require 'csv'
    require 'roo'

    ext = File.extname(@file.original_filename).downcase
    rows = case ext
           when '.csv'
             parse_csv
           when '.xlsx', '.xls'
             parse_excel
           else
             return { success: false, error: 'Formato no soportado. Use CSV o Excel.' }
           end

    import_rows(rows)
  rescue StandardError => e
    { success: false, error: "Error al procesar archivo: #{e.message}" }
  end

  private

  def parse_csv
    content = @file.read.force_encoding('UTF-8')
    CSV.parse(content, headers: true).map(&:to_h)
  end

  def parse_excel
    spreadsheet = Roo::Spreadsheet.open(@file.path)
    sheet = spreadsheet.sheet(0)
    headers = sheet.row(1).map { |h| h.to_s.strip }
    rows = []
    (2..sheet.last_row).each do |i|
      row = {}
      headers.each_with_index do |header, j|
        row[header] = sheet.cell(i, j + 1)
      end
      rows << row
    end
    rows
  end

  def import_rows(rows)
    created = 0
    updated = 0
    errors = []

    rows.each_with_index do |row, i|
      description = row['DESCRIPCION']&.to_s&.strip
      variant = row['MODELO']&.to_s&.strip
      cost_usd = row['COSTO']&.to_d
      divisor = row['DIVISA']&.to_i
      cost_bs = row['MONTO Bs']&.to_d
      bolivares = row['BOLIVARES']&.to_i

      next if description.blank?

      price = @account.vehicle_prices.find_or_initialize_by(
        description: description,
        variant: variant
      )

      price.assign_attributes(
        cost_usd: cost_usd,
        divisor: divisor,
        cost_bs: cost_bs,
        bolivares: bolivares
      )

      if price.save
        price.new_record? ? created += 1 : updated += 1
      else
        errors << { row: i + 2, errors: price.errors.full_messages }
      end
    end

    {
      success: true,
      created: created,
      updated: updated,
      total: rows.size,
      errors: errors
    }
  end
end
