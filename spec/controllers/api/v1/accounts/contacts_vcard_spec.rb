require 'rails_helper'

RSpec.describe 'Contacts vCard export', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:url) { "/api/v1/accounts/#{account.id}/contacts/vcard" }

  it 'hands the phone one card per contact with a number' do
    create(:contact, account: account, name: 'Pérez, Ricardo', phone_number: '+584141234567')
    create(:contact, account: account, name: 'Sin número', phone_number: nil)

    get url, headers: admin.create_new_auth_token

    expect(response).to have_http_status(:success)
    expect(response.media_type).to eq('text/vcard')
    expect(response.body.scan('BEGIN:VCARD').size).to eq(1)
    # The comma is escaped, otherwise the phone reads it as a field separator.
    expect(response.body).to include("FN:Pérez\\, Ricardo\r\nTEL;TYPE=CELL:+584141234567\r\n")
  end

  it 'is for administrators only' do
    agent = create(:user, account: account, role: :agent)

    get url, headers: agent.create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
  end
end
