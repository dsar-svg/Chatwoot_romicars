# frozen_string_literal: true

class VehiclePriceImportService
  MODEL_MAPPING = {
    'BUS/VAN/TRUCK' => ['DONGFENG', 'MINI'],
    'BRAVA' => ['DONGFENG', 'MINI'],
    'ZNA' => ['DONGFENG', 'ZNA'],
    'S30' => ['DONGFENG', 'S30'],
    'HAIMA7' => ['HAIMA', 'HAIMA 7'],
    'HAIMA 7' => ['HAIMA', 'HAIMA 7'],
    'ZOTYE' => ['ZOTYE', 'NOMADA'],
    'CHANA' => ['CHANA', 'CHANA 1.1'],
    'ARAUCA' => ['CHERY', 'ARAUCA'],
    'ORINOCO' => ['CHERY', 'ORINOCO'],
    'X1' => ['CHERY', 'X1'],
    '2018' => ['CHERY', 'QQ 2018'],
    'TIGGO 2.0' => ['CHERY', 'TIGGO 2.0'],
    'TIGGO 2.4' => ['CHERY', 'TIGGO 2.0'],
    'TIUNA X5' => ['CHERY', 'TIUNA X5'],
    'H5' => ['CHERY', 'PANEL H5'],
    'GRAND TIGGO' => ['CHERY', 'GRAN TIGGO']
  }.freeze

  def initialize(account, file)
    @account = account
    @file = file
    @skipped = []
  end

  def call
    require 'csv'

    filename = @file.respond_to?(:original_filename) ? @file.original_filename : @file.path.to_s
    ext = File.extname(filename).downcase
    rows = case ext
           when '.csv'
             parse_csv
           when '.xlsx', '.xls'
             parse_excel
           else
             return { success: false, error: 'Formato no soportado. Use CSV o Excel.' }
           end

    import_rows(rows)
  rescue LoadError
    { success: false, error: 'Importación de Excel no disponible. Convierta el archivo a CSV.' }
  rescue StandardError => e
    { success: false, error: "Error al procesar archivo: #{e.message}" }
  end

  private

  def parse_csv
    content = @file.read
    utf8 = content.dup.force_encoding('UTF-8')
    unless utf8.valid_encoding?
      utf8 = content.dup.force_encoding('Windows-1252').encode('UTF-8', invalid: :replace, undef: :replace)
    end
    CSV.parse(utf8, headers: true).map(&:to_h)
  end

  def parse_excel
    require 'roo'

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
      variant = normalize_variant(row['MODELO'])
      mapping = MODEL_MAPPING[variant]

      next if description.blank?

      unless mapping
        @skipped << { row: i + 2, description: description, variant: variant }
        next
      end

      brand = @account.vehicle_brands.find_or_create_by!(name: mapping[0])
      model = @account.vehicle_models.find_or_create_by!(vehicle_brand: brand, name: mapping[1])

      price = @account.vehicle_prices.find_or_initialize_by(
        description: description,
        variant: variant
      )
      was_new = price.new_record?

      price.assign_attributes(
        vehicle_brand: brand,
        vehicle_model: model,
        cost_usd: row['COSTO']&.to_d,
        divisa: row['DIVISA']&.to_i,
        monto_bs: row['MONTO Bs']&.to_d,
        bolivares: row['BOLIVARES']&.to_i,
        synonyms: row['SINONIMOS']&.to_s&.strip
      )

      if price.save
        was_new ? created += 1 : updated += 1
      else
        errors << { row: i + 2, errors: price.errors.full_messages }
      end
    end

    {
      success: true,
      created: created,
      updated: updated,
      skipped: @skipped,
      total: rows.size,
      errors: errors
    }
  end

  def normalize_variant(value)
    value.to_s.strip.upcase.gsub(',', '.').squeeze(' ').strip
  end
end
