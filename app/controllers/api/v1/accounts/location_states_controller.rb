# frozen_string_literal: true

class Api::V1::Accounts::LocationStatesController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  def index
    @states = Current.account.location_states.active.ordered
  end
end
