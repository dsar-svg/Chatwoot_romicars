class BotLogPolicy < ApplicationPolicy
  def index?
    account_user.admin?
  end

  def show?
    account_user.admin?
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    account_user.admin?
  end
end
