# frozen_string_literal: true

class Api::V1::Accounts::ExchangeRatesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @rates = Current.account.exchange_rates.ordered
  end

  def show
    @rate = Current.account.exchange_rates.find(params[:id])
  end

  def create
    @rate = Current.account.exchange_rates.new(rate_params)
    @rate.save!
    render :show
  end

  def fetch_current
    result = ExchangeRate.fetch_bcv_rate
    return render json: { error: 'No se pudo obtener la tasa BCV' }, status: :unprocessable_entity unless result

    # Same path as FetchExchangeRatesJob: store under the rate's own date, reprice in one UPDATE.
    @rate = ExchangeRate.apply!(Current.account, result)
    render :show
  end

  # Changes what is added to the BCV rate. The latest rate's equivalent and every price are
  # redone with it right away: the bot quotes the stored amounts.
  def markup
    percent = BigDecimal(params[:percent].to_s, exception: false)
    unless percent&.between?(0, 100)
      return render json: { error: 'El porcentaje debe estar entre 0 y 100' }, status: :unprocessable_entity
    end

    Current.account.update!(price_markup_percent: percent.to_s('F'))
    @rate = Current.account.exchange_rates.ordered.first
    return render json: { payload: nil, markup_percent: percent } if @rate.nil?

    @rate.update!(equiv_13: ExchangeRate.equiv_for(@rate.rate, percent))
    ExchangeRate.recalculate_prices!(Current.account, @rate)
    render :show
  end

  private

  def rate_params
    params.require(:exchange_rate).permit(:rate, :equiv_13, :effective_date, :source)
  end
end
