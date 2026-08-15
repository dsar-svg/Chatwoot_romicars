# frozen_string_literal: true

class Api::V1::Accounts::VehicleBrandsController < Api::V1::Accounts::BaseController
  before_action :fetch_brand, only: [:show, :update, :destroy]

  def index
    @brands = Current.account.vehicle_brands.ordered
  end

  def show; end

  def create
    @brand = Current.account.vehicle_brands.new(brand_params)
    @brand.save!
    render :show
  end

  def update
    @brand.update!(brand_params)
    render :show
  end

  def destroy
    @brand.destroy!
    head :ok
  end

  private

  def fetch_brand
    @brand = Current.account.vehicle_brands.find(params[:id])
  end

  def brand_params
    params.require(:vehicle_brand).permit(:name, :active)
  end
end
