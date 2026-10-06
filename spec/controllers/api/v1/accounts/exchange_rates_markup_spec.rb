require 'rails_helper'

RSpec.describe 'Exchange rate markup', type: :request do
  let!(:account) { create(:account) }
  let!(:brand) { create(:vehicle_brand, account: account) }
  let!(:rate) { account.exchange_rates.create!(rate: 100, equiv_13: 113, effective_date: Date.current) }
  let!(:price) { account.vehicle_prices.create!(vehicle_brand: brand, description: 'Pastilla', divisa: 25) }
  let(:url) { "/api/v1/accounts/#{account.id}/exchange_rates/markup" }

  it 'changes the markup and reprices the catalogue with it' do
    admin = create(:user, account: account, role: :administrator)

    patch url, params: { percent: 20 }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['markup_percent'].to_d).to eq(20)
    expect(account.reload.price_markup_percent).to eq(20)
    expect(rate.reload.equiv_13).to eq(120)
    expect(price.reload).to have_attributes(monto_bs: 3000, bolivares: 30)
  end

  it 'rejects a percentage out of range' do
    admin = create(:user, account: account, role: :administrator)

    patch url, params: { percent: 150 }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(price.reload.monto_bs).to eq(2825)
  end

  it 'does not let agents change the markup' do
    agent = create(:user, account: account, role: :agent)

    patch url, params: { percent: 20 }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(rate.reload.equiv_13).to eq(113)
  end
end
