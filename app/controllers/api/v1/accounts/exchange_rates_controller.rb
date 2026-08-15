# frozen_string_literal: true

class Api::V1::Accounts::ExchangeRatesController < Api::V1::Accounts::BaseController
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
    if result
      today = Date.current
      @rate = Current.account.exchange_rates.find_or_initialize_by(effective_date: today)
      @rate.assign_attributes(result.merge(effective_date: today))
      @rate.save!
      render :show
    else
      render json: { error: 'No se pudo obtener la tasa BCV' }, status: :unprocessable_entity
    end
  end

  private

  def rate_params
    params.require(:exchange_rate).permit(:rate, :equiv_13, :effective_date, :source)
  end
end
