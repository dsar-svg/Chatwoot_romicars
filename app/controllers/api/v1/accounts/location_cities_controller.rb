# frozen_string_literal: true

class Api::V1::Accounts::LocationCitiesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @cities = Current.account.location_cities
                     .active
                     .by_state(params[:state_id])
                     .includes(:location_state)
                     .ordered
  end
end
