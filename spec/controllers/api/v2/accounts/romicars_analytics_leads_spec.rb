require 'rails_helper'

RSpec.describe 'RomiCars Analytics leads', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:customer) { create(:contact, account: account) }

  # The dashboard only counts conversations where the customer wrote. An incoming message
  # reopens a resolved conversation, so put the status back afterwards.
  def lead(**attrs)
    conversation = create(:conversation, account: account, **attrs)
    create(:message, account: account, conversation: conversation, message_type: :incoming)
    conversation.update_columns(status: Conversation.statuses[attrs.fetch(:status, :open)]) # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  def get_json(path)
    get "/api/v2/accounts/#{account.id}/romicars_analytics/#{path}", headers: admin.create_new_auth_token, as: :json
    response.parsed_body
  end

  it 'counts one lead per customer and leaves suppliers out' do
    # Asked on Instagram, bought on WhatsApp: two conversations, one merged contact, one lead.
    lead(contact: customer, status: :resolved, resolution_type: 'derivado')
    lead(contact: customer, status: :resolved, resolution_type: 'ganado', sale_amount: 40)
    lead
    supplier = create(:contact, account: account)
    supplier.add_labels(['proveedor'])
    lead(contact: supplier)

    kpis = get_json('overview')['kpis']

    expect(kpis['total_leads']).to eq(2)
    expect(kpis['conversion']).to eq(50.0)
  end

  it 'leaves out the contacts used to try the bot' do
    lead(contact: customer)
    tester = create(:contact, account: account)
    tester.add_labels(['prueba-bot'])
    lead(contact: tester, status: :resolved, resolution_type: 'ganado', sale_amount: 15)

    expect(get_json('overview')['kpis']).to include('total_leads' => 1, 'conversion' => 0)
    expect(get_json('resolution')['ganado']['count']).to eq(0)
  end

  it 'drops the cached AI answers when a conversation closes with an outcome' do
    conversation = lead(contact: customer)
    keys = [RomicarsInsightsCache.ai_insights_key(account.id), RomicarsInsightsCache.win_loss_key(account.id)]
    keys.each { |key| Redis::Alfred.setex(key, '{}', 1.hour) }

    conversation.update!(priority: :high)
    expect(keys.map { |key| Redis::Alfred.get(key) }).to all(be_present)

    conversation.resolve_with_outcome(resolution_type: 'ganado', sale_amount: 40)
    expect(keys.map { |key| Redis::Alfred.get(key) }).to all(be_nil)
  end

  it 'leaves out conversations from before the launch, not their customers' do
    lead(contact: customer, status: :resolved).add_labels(['previo-arranque'])
    expect(get_json('overview')['kpis']['total_leads']).to eq(0)

    lead(contact: customer)
    expect(get_json('overview')['kpis']['total_leads']).to eq(1)
  end

  it 'leaves out broadcast recipients who never wrote' do
    lead(contact: customer)
    # What a broadcast from the WhatsApp Business app leaves: a new contact and an open
    # conversation holding only the shop's own echo.
    echo = create(:conversation, account: account)
    create(:message, account: account, conversation: echo, message_type: :outgoing,
                     content_attributes: { external_echo: true })

    overview = get_json('overview')

    expect(overview['kpis']).to include('total_leads' => 1, 'active_chats' => 1)
    expect(overview['mini_metrics']['new_today']).to eq(1)
  end

  it 'credits a seller with sales, not with every close' do
    seller = create(:user, account: account, role: :agent)
    lead(assignee: seller, status: :resolved, resolution_type: 'ganado', sale_amount: 40)
    lead(assignee: seller, status: :resolved, resolution_type: 'abandonado')

    row = get_json('agents').find { |agent| agent['id'] == seller.id }

    expect(row).to include('assigned' => 2, 'resolved' => 2, 'won' => 1, 'conversion' => 50.0)
  end

  it 'lists administrators who take conversations' do
    lead(assignee: admin)

    row = get_json('agents').find { |agent| agent['id'] == admin.id }

    expect(row).to include('assigned' => 1)
  end
end
