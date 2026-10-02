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
end
