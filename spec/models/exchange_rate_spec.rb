# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExchangeRate do
  let(:account) { create(:account) }
  let(:bcv_page) do
    <<~HTML
      <div id="euro"><strong> 984,26261811 </strong></div>
      <div id="dolar" class="col-sm-12"><div class="field-content">
        <span> USD</span><strong class="strong-tb"> 873,86700000 </strong>
      </div></div>
      <div>Fecha Valor: <span class="date-display-single" content="2026-10-07T00:00:00-04:00">Miércoles, 07 Octubre 2026</span></div>
    HTML
  end
  let(:fallback_body) { [{ fuente: 'oficial', promedio: 872.3927 }, { fuente: 'paralelo', promedio: 991.99 }].to_json }

  describe '.fetch_bcv_rate' do
    it 'reads the dollar and its date from the BCV page' do
      stub_request(:get, described_class::BCV_URL).to_return(body: bcv_page)

      expect(described_class.fetch_bcv_rate).to eq(rate: BigDecimal('873.87'), effective_date: Date.new(2026, 10, 7), source: 'bcv.org.ve')
    end

    it 'falls back to the API when the BCV page does not answer' do
      stub_request(:get, described_class::BCV_URL).to_return(status: 503)
      stub_request(:get, described_class::FALLBACK_API_URL).to_return(body: fallback_body)

      expect(described_class.fetch_bcv_rate).to include(rate: BigDecimal('872.39'), source: 've.dolarapi.com')
    end

    it 'refuses a rate far from the last one' do
      account.exchange_rates.create!(rate: 400, equiv_13: 452, effective_date: Date.current)
      stub_request(:get, described_class::BCV_URL).to_return(body: bcv_page)
      stub_request(:get, described_class::FALLBACK_API_URL).to_return(body: fallback_body)

      expect(described_class.fetch_bcv_rate).to be_nil
    end
  end

  describe '.apply!' do
    let(:brand) { create(:vehicle_brand, account: account) }
    let(:price) { account.vehicle_prices.create!(vehicle_brand: brand, description: 'Filtro de aceite', divisa: 10) }

    it 'stores the rate under its own date with the account markup and reprices' do
      account.update!(price_markup_percent: '20')
      price

      rate = described_class.apply!(account, rate: BigDecimal('100'), effective_date: Date.new(2026, 10, 7), source: 'bcv.org.ve')

      expect(rate).to have_attributes(effective_date: Date.new(2026, 10, 7), equiv_13: 120)
      expect(price.reload).to have_attributes(monto_bs: 1200, bolivares: 12)
    end

    it 'uses 13% for an account that never set a markup' do
      rate = described_class.apply!(account, rate: BigDecimal('100'), effective_date: Date.current, source: 'bcv.org.ve')

      expect(rate.equiv_13).to eq(113)
    end
  end
end
