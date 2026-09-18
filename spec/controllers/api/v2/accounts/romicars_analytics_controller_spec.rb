require 'rails_helper'

RSpec.describe 'RomiCars Analytics API', type: :request do
  let(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }

  describe 'GET /api/v2/accounts/{account.id}/romicars_analytics/win_loss' do
    let!(:lost_with_chat) do
      create(:conversation, account: account, status: :resolved, resolution_type: 'perdido',
                            resolution_reason: 'precio', resolved_at: 1.day.ago)
    end

    before do
      create(:message, account: account, conversation: lost_with_chat, message_type: :incoming,
                       content: 'Cuanto cuesta la bomba de agua?')
      create(:message, account: account, conversation: lost_with_chat, message_type: :outgoing,
                       content: 'Son 80 dolares.')

      create_list(:conversation, 2, account: account, status: :resolved, resolution_type: 'perdido',
                                    resolution_reason: 'sin_stock', requested_product: 'Bomba de agua',
                                    resolved_at: 2.days.ago)
      create(:conversation, account: account, status: :resolved, resolution_type: 'ganado',
                            sale_amount: 120.5, sale_date: Date.current, resolved_at: 1.day.ago)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v2/accounts/#{account.id}/romicars_analytics/win_loss"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when OpenAI is not configured' do
      it 'returns the counts with the static narrative' do
        with_modified_env OPENAI_API_KEY: nil do
          get "/api/v2/accounts/#{account.id}/romicars_analytics/win_loss",
              headers: admin.create_new_auth_token, as: :json
        end

        expect(response).to have_http_status(:success)

        body = response.parsed_body
        expect(body['source']).to eq('rules')
        expect(body['perdidas']['total']).to eq(3)
        expect(body['ganadas']['total']).to eq(1)

        top_cause = body['perdidas']['causas'].first
        expect(top_cause['motivo']).to eq('sin_stock')
        expect(top_cause['cantidad']).to eq(2)
        expect(top_cause['pct']).to eq(66.7)
        expect(top_cause['diagnostico']).to be_present
        expect(top_cause['accion']).to be_present

        expect(body['perdidas']['repuestos_sin_stock']).to include('producto' => 'Bomba de agua', 'veces' => 2)
        expect(body['ganadas']['practicas'].pluck('clave')).to include('canal')
        expect(body['perdidas']['patrones']).to eq([])
      end
    end

    context 'when OpenAI answers' do
      let(:openai_client) { instance_double(OpenAI::Client) }
      let(:answer) do
        {
          'perdidas' => {
            'resumen' => 'Resumen de la IA',
            'causas' => { 'sin_stock' => { 'diagnostico' => 'Diagnostico IA', 'accion' => 'Accion IA' } },
            'patrones' => [
              {
                'hallazgo' => 'Se cae por precio',
                'evidencia' => 'El cliente pregunta precio y no vuelve a escribir.',
                'accion' => 'Ofrecer alternativa mas barata en el mismo mensaje.',
                'conversaciones' => [lost_with_chat.display_id, 999_999]
              }
            ]
          },
          'ganadas' => {
            'resumen' => 'Ganadas IA',
            'practicas' => { 'canal' => { 'practica' => 'Practica IA', 'accion' => 'Repetir IA' } }
          }
        }
      end

      before do
        allow(OpenAI::Client).to receive(:new).and_return(openai_client)
        allow(openai_client).to receive(:chat).and_return(
          { 'choices' => [{ 'message' => { 'content' => answer.to_json } }] }
        )
      end

      # The model writes the narrative and nothing else: the counts must stay exactly as
      # the SQL produced them even though the answer never carries them.
      it 'uses the AI narrative but keeps the counts from the database' do
        with_modified_env OPENAI_API_KEY: 'test-key' do
          get "/api/v2/accounts/#{account.id}/romicars_analytics/win_loss",
              headers: admin.create_new_auth_token, as: :json
        end

        expect(response).to have_http_status(:success)

        body = response.parsed_body
        expect(body['source']).to eq('ai')
        expect(body['perdidas']['resumen']).to eq('Resumen de la IA')
        expect(body['perdidas']['total']).to eq(3)

        top_cause = body['perdidas']['causas'].first
        expect(top_cause['cantidad']).to eq(2)
        expect(top_cause['diagnostico']).to eq('Diagnostico IA')
        expect(top_cause['accion']).to eq('Accion IA')

        pattern = body['perdidas']['patrones'].first
        expect(pattern['hallazgo']).to eq('Se cae por precio')
        # 999999 was never sent to the model, so it must not reach the panel as a link.
        expect(pattern['conversaciones']).to eq([lost_with_chat.display_id])

        canal = body['ganadas']['practicas'].find { |practica| practica['clave'] == 'canal' }
        expect(canal['practica']).to eq('Practica IA')
        expect(canal['accion']).to eq('Repetir IA')
      end

      # `refresh` skips the response cache, so without the read memory this second call
      # would send the very same transcripts to the model again.
      it 'does not send conversations it already read' do
        with_modified_env OPENAI_API_KEY: 'test-key' do
          get "/api/v2/accounts/#{account.id}/romicars_analytics/win_loss",
              headers: admin.create_new_auth_token, as: :json
          get "/api/v2/accounts/#{account.id}/romicars_analytics/win_loss",
              params: { refresh: 1 }, headers: admin.create_new_auth_token, as: :json
        end

        expect(openai_client).to have_received(:chat).once

        body = response.parsed_body
        expect(body['conversaciones_nuevas']).to eq(0)
        expect(body['conversaciones_analizadas']).to eq(4)
        expect(body['perdidas']['patrones'].first['hallazgo']).to eq('Se cae por precio')
      end
    end
  end
end
