# frozen_string_literal: true

class Api::V1::Accounts::VehiclePricesController < Api::V1::Accounts::BaseController
  before_action :fetch_price, only: [:show, :update, :destroy]

  def index
    @prices = Current.account.vehicle_prices
                     .by_brand(params[:brand_id])
                     .by_model(params[:model_id])
                     .by_search(params[:search])
                     .ordered
  end

  def show; end

  def create
    @price = Current.account.vehicle_prices.new(price_params)
    @price.save!
    render :show
  end

  def update
    @price.update!(price_params)
    render :show
  end

  def destroy
    @price.destroy!
    head :ok
  end

  def import
    return render json: { error: 'No file provided' }, status: :bad_request unless params[:file]

    result = VehiclePriceImportService.new(Current.account, params[:file]).call
    render json: result, status: result[:success] ? :ok : :unprocessable_entity
  end

  private

  def fetch_price
    @price = Current.account.vehicle_prices.find(params[:id])
  end

  def price_params
    params.require(:vehicle_price).permit(
      :vehicle_brand_id, :vehicle_model_id, :description,
      :variant, :cost_usd, :divisor, :cost_bs, :bolivares, :active, :synonyms
    )
  end
end
