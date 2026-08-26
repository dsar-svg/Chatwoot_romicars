class VehiclePricePolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    account_user.admin?
  end

  def update?
    account_user.admin?
  end

  def destroy?
    account_user.admin?
  end
end
