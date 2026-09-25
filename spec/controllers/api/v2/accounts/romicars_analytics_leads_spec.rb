require 'rails_helper'

RSpec.describe 'RomiCars Analytics leads', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:customer) { create(:contact, account: account) }

  def get_json(path)
    get "/api/v2/accounts/#{account.id}/romicars_analytics/#{path}", headers: admin.create_new_auth_token, as: :json
    response.parsed_body
  end

  it 'counts one lead per customer and leaves suppliers out' do
    # Asked on Instagram, bought on WhatsApp: two conversations, one merged contact, one lead.
    create(:conversation, account: account, contact: customer, status: :resolved, resolution_type: 'derivado')
    create(:conversation, account: account, contact: customer, status: :resolved, resolution_type: 'ganado', sale_amount: 40)
    create(:conversation, account: account)
    supplier = create(:contact, account: account)
    supplier.add_labels(['proveedor'])
    create(:conversation, account: account, contact: supplier)

    kpis = get_json('overview')['kpis']

    expect(kpis['total_leads']).to eq(2)
    expect(kpis['conversion']).to eq(50.0)
  end

  it 'credits a seller with sales, not with every close' do
    seller = create(:user, account: account, role: :agent)
    create(:conversation, account: account, assignee: seller, status: :resolved, resolution_type: 'ganado', sale_amount: 40)
    create(:conversation, account: account, assignee: seller, status: :resolved, resolution_type: 'abandonado')

    row = get_json('agents').find { |agent| agent['id'] == seller.id }

    expect(row).to include('assigned' => 2, 'resolved' => 2, 'won' => 1, 'conversion' => 50.0)
  end
end
