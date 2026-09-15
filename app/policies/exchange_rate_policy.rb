class ExchangeRatePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    account_user.administrator?
  end

  def update?
    account_user.administrator?
  end

  def destroy?
    account_user.administrator?
  end

  # Same as VehiclePricePolicy#import? — without this the "actualizar tasa BCV" button
  # errored out instead of refreshing the rate.
  def fetch_current?
    account_user.administrator?
  end
end
