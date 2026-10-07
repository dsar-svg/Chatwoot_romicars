require 'rails_helper'

RSpec.describe VehiclePriceExportService do
  let(:account) { create(:account) }
  let(:brand) { create(:vehicle_brand, account: account) }

  def reimport(xlsx)
    file = Tempfile.new(['precios', '.xlsx'])
    file.binmode
    file.write(xlsx)
    file.flush
    VehiclePriceImportService.new(account, file).call
  ensure
    file&.close!
  end

  it 'exports a file the import reads back onto the same rows' do
    mapped = account.vehicle_prices.create!(vehicle_brand: brand, description: 'Pastilla de freno delantera', variant: 'ARAUCA',
                                            divisa: 25, bolivares: 28, cost_usd: 12.5, available: false)
    manual = account.vehicle_prices.create!(vehicle_brand: brand, description: 'Bomba de agua & sello', variant: 'Tiggo 4 Pro',
                                            divisa: 40)
    # Edited on screen only: the file has no column for it, so it stays out of the export.
    account.vehicle_prices.create!(description: 'Combo de filtros', kind: 'combo', divisa: 14)
    xlsx = described_class.new(account).call
    mapped.update!(available: true, divisa: 1)
    manual.update!(divisa: 1)

    result = reimport(xlsx)

    expect(result).to include(success: true, created: 0, updated: 2, skipped: [])
    expect(mapped.reload).to have_attributes(available: false, divisa: 25, cost_usd: 12.5)
    expect(manual.reload).to have_attributes(available: true, divisa: 40, vehicle_brand_id: brand.id)
  end
end
