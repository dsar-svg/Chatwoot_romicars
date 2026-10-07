require 'rails_helper'

RSpec.describe VehiclePrice do
  let(:account) { create(:account) }
  let(:brand) { create(:vehicle_brand, account: account) }

  it 'computes the bolivar amounts from divisa and the latest rate' do
    account.exchange_rates.create!(rate: 100, equiv_13: 113, effective_date: Date.yesterday)
    price = account.vehicle_prices.create!(vehicle_brand: brand, description: 'Pastilla', divisa: 25)

    expect(price).to have_attributes(monto_bs: 2825, bolivares: 28)

    price.update!(divisa: 30, monto_bs: nil, bolivares: nil)
    expect(price.reload).to have_attributes(monto_bs: 3390, bolivares: 34)
  end

  it 'needs a brand for a part but not for a promotion that covers every brand' do
    expect(account.vehicle_prices.new(description: 'Pastilla')).not_to be_valid
    expect(account.vehicle_prices.new(description: '10% en filtros', kind: 'promocion')).to be_valid
    expect(account.vehicle_prices.new(description: 'Otro', kind: 'oferta', vehicle_brand: brand)).not_to be_valid
  end

  it 'keeps combos and promotions out of the part scope' do
    part = account.vehicle_prices.create!(vehicle_brand: brand, description: 'Filtro de aceite')
    account.vehicle_prices.create!(description: 'Combo de filtros', kind: 'combo')

    expect(account.vehicle_prices.parts).to eq([part])
  end
end
