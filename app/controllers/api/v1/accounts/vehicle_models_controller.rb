# frozen_string_literal: true

class Api::V1::Accounts::VehicleModelsController < Api::V1::Accounts::BaseController
  before_action :check_authorization
  before_action :fetch_model, only: [:show, :update, :destroy]

  def index
    @models = Current.account.vehicle_models
                     .by_brand(params[:brand_id])
                     .ordered
  end

  def show; end

  def create
    @model = Current.account.vehicle_models.new(model_params)
    @model.save!
    render :show
  end

  def update
    @model.update!(model_params)
    render :show
  end

  def destroy
    @model.destroy!
    head :ok
  end

  private

  def fetch_model
    @model = Current.account.vehicle_models.find(params[:id])
  end

  def model_params
    params.require(:vehicle_model).permit(:vehicle_brand_id, :name, :active)
  end
end
