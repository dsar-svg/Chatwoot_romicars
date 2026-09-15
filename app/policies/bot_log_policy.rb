class BotLogPolicy < ApplicationPolicy
  def index?
    account_user.administrator?
  end

  def show?
    account_user.administrator?
  end

  def create?
    false
  end

  def update?
    false
  end

  def destroy?
    account_user.administrator?
  end
end
