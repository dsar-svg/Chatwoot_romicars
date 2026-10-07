# frozen_string_literal: true

# Writes the price list as an .xlsx in the exact layout VehiclePriceImportService reads, so the
# store can download it, edit prices or the DISPONIBLE column in Excel and upload it back.
# Built by hand with rubyzip (already a dependency of roo): no gem writes xlsx in this bundle, and
# a CSV opens as a single column in Excel when the regional list separator is ";".
# The bolivar amounts are left out: VehiclePrice computes them from DIVISA and the latest rate.
class VehiclePriceExportService
  HEADERS = %w[DESCRIPCION MODELO COSTO DIVISA SINONIMOS DISPONIBLE].freeze
  COLUMNS = ('A'..'F').to_a.freeze
  WIDTHS = [50, 16, 10, 10, 40, 12].freeze

  XML = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
  MAIN = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'
  RELS = 'http://schemas.openxmlformats.org/package/2006/relationships'
  DOC_RELS = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
  OFFICE = 'application/vnd.openxmlformats-officedocument.spreadsheetml'

  STATIC_PARTS = {
    '[Content_Types].xml' => "#{XML}<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">" \
                             "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>" \
                             '<Default Extension="xml" ContentType="application/xml"/>' \
                             "<Override PartName=\"/xl/workbook.xml\" ContentType=\"#{OFFICE}.sheet.main+xml\"/>" \
                             "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"#{OFFICE}.worksheet+xml\"/>" \
                             "<Override PartName=\"/xl/styles.xml\" ContentType=\"#{OFFICE}.styles+xml\"/></Types>",
    '_rels/.rels' => "#{XML}<Relationships xmlns=\"#{RELS}\">" \
                     "<Relationship Id=\"rId1\" Type=\"#{DOC_RELS}/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>",
    'xl/workbook.xml' => "#{XML}<workbook xmlns=\"#{MAIN}\" xmlns:r=\"#{DOC_RELS}\">" \
                         '<sheets><sheet name="Precios" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels' => "#{XML}<Relationships xmlns=\"#{RELS}\">" \
                                    "<Relationship Id=\"rId1\" Type=\"#{DOC_RELS}/worksheet\" Target=\"worksheets/sheet1.xml\"/>" \
                                    "<Relationship Id=\"rId2\" Type=\"#{DOC_RELS}/styles\" Target=\"styles.xml\"/></Relationships>",
    # Style 1 is the bold header.
    'xl/styles.xml' => "#{XML}<styleSheet xmlns=\"#{MAIN}\">" \
                       '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>' \
                       '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>' \
                       '<fills count="2"><fill><patternFill patternType="none"/></fill>' \
                       '<fill><patternFill patternType="gray125"/></fill></fills>' \
                       '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' \
                       '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' \
                       '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' \
                       '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>' \
                       '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>'
  }.freeze

  def initialize(account)
    @account = account
  end

  def call
    require 'zip'

    Zip::OutputStream.write_buffer do |zip|
      STATIC_PARTS.merge('xl/worksheets/sheet1.xml' => sheet_xml).each do |name, xml|
        zip.put_next_entry(name)
        zip.write(xml)
      end
    end.string
  end

  private

  def rows
    @account.vehicle_prices.parts.ordered.map do |price|
      [price.description, price.variant, price.cost_usd, price.divisa, price.synonyms, price.available ? 'SI' : 'NO']
    end
  end

  def sheet_xml
    header = HEADERS.each_with_index.map { |title, j| cell("#{COLUMNS[j]}1", title, style: 1) }
    body = rows.each_with_index.map do |values, i|
      cells = values.each_with_index.filter_map { |value, j| cell("#{COLUMNS[j]}#{i + 2}", value) }
      "<row r=\"#{i + 2}\">#{cells.join}</row>"
    end
    cols = WIDTHS.each_with_index.map { |width, j| "<col min=\"#{j + 1}\" max=\"#{j + 1}\" width=\"#{width}\" customWidth=\"1\"/>" }

    "#{XML}<worksheet xmlns=\"#{MAIN}\"><cols>#{cols.join}</cols>" \
      "<sheetData><row r=\"1\">#{header.join}</row>#{body.join}</sheetData></worksheet>"
  end

  def cell(ref, value, style: 0)
    return if value.blank?
    # BigDecimal#to_s is scientific ("0.125e2"); Excel wants plain digits.
    return "<c r=\"#{ref}\"><v>#{value.is_a?(BigDecimal) ? value.to_s('F') : value}</v></c>" if value.is_a?(Numeric)

    text = value.to_s.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '')
    "<c r=\"#{ref}\" s=\"#{style}\" t=\"inlineStr\"><is><t>#{ERB::Util.html_escape(text)}</t></is></c>"
  end
end
