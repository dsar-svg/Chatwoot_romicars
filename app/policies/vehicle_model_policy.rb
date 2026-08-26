class VehicleModelPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    account_user.admin? || account_user.agent?
  end

  def update?
    account_user.admin? || account_user.agent?
  end

  def destroy?
    account_user.admin?
  end
end
