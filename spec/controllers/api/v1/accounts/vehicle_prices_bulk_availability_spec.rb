require 'rails_helper'

RSpec.describe 'Vehicle prices bulk availability', type: :request do
  let!(:account) { create(:account) }
  let!(:brand) { create(:vehicle_brand, account: account) }
  let!(:prices) { Array.new(3) { |i| account.vehicle_prices.create!(vehicle_brand: brand, description: "Pastilla #{i}") } }
  let(:url) { "/api/v1/accounts/#{account.id}/vehicle_prices/bulk_availability" }

  it 'marks only the selected parts as sold out' do
    admin = create(:user, account: account, role: :administrator)

    patch url, params: { ids: prices.first(2).map(&:id), available: false }, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['updated']).to eq(2)
    expect(prices.map { |price| price.reload.available }).to eq([false, false, true])
  end

  it 'does not let agents change availability' do
    agent = create(:user, account: account, role: :agent)

    patch url, params: { ids: [prices.first.id], available: false }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(prices.first.reload.available).to be(true)
  end
end
