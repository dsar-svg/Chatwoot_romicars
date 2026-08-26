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
    if result
      today = Date.current
      @rate = Current.account.exchange_rates.find_or_initialize_by(effective_date: today)
      @rate.assign_attributes(result.merge(effective_date: today))
      @rate.save!

      recalculate_prices(result[:equiv_13])

      render :show
    else
      render json: { error: 'No se pudo obtener la tasa BCV' }, status: :unprocessable_entity
    end
  end

  private

  def rate_params
    params.require(:exchange_rate).permit(:rate, :equiv_13, :effective_date, :source)
  end

  def recalculate_prices(equiv_13)
    tasa_bcv = equiv_13 / 1.13
    Current.account.vehicle_prices.find_each do |price|
      next unless price.divisa.present?

      new_monto_bs = (price.divisa * equiv_13).round(2)
      new_bolivares = (new_monto_bs / tasa_bcv).round(2)

      price.update_columns(
        monto_bs: new_monto_bs,
        bolivares: new_bolivares
      )
    end
  end
end
