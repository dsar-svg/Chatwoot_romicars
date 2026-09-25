require 'rails_helper'

RSpec.describe 'Conversation WhatsApp handoff API', type: :request do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:agent_bot) { create(:agent_bot, account: account) }
  let(:url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/whatsapp_handoff" }

  before do
    create(:channel_whatsapp, account: account, phone_number: '+584244205394', sync_templates: false, validate_provider_config: false)
    create(:agent_bot_inbox, inbox: conversation.inbox, agent_bot: agent_bot)
  end

  it 'rejects a request without a token' do
    post url, params: { repuesto: 'kit de clutch' }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  # The bot calls this with its own token, like toggle_status. Without the entry in
  # BOT_ACCESSIBLE_ENDPOINTS it gets a 401 and the customer never sees the link.
  it 'hands the bot a wa.me link' do
    post url, headers: { api_access_token: agent_bot.access_token.token }, params: { repuesto: 'kit de clutch' }, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['link']).to start_with('https://wa.me/584244205394?text=')
  end

  it 'saves the number the customer typed' do
    patch url, headers: { api_access_token: agent_bot.access_token.token }, params: { telefono: '0414-1234567' }, as: :json

    expect(response).to have_http_status(:success)
    expect(conversation.contact.reload.phone_number).to eq('+584141234567')
  end

  it 'tells the bot to ask again when the number is not one' do
    patch url, headers: { api_access_token: agent_bot.access_token.token }, params: { telefono: '1234' }, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body['error']).to include('Pídele el número de nuevo')
  end
end
