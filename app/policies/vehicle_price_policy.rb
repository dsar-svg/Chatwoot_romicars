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

  # Pundit derives the query from the action name, so the custom `import` collection
  # action had no matching predicate here and every CSV upload blew up before reaching
  # the controller.
  def import?
    account_user.admin?
  end
end
