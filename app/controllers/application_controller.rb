class ApplicationController < ActionController::Base
  include DeviseTokenAuth::Concerns::SetUserByToken
  include RequestExceptionHandler
  include Pundit::Authorization
  include SwitchLocale
  include TrackSessionActivity

  # Devise controllers are exempt alongside /api/. Everything served through here
  # authenticates with devise_token_auth headers (access-token / client / uid), which a
  # cross-origin page cannot set, so there is no CSRF exposure to protect against — and the
  # frontend never sends a CSRF token, so requiring one simply rejects every /auth/ call
  # with 422: sign in, sign out and password reset all stop working.
  #
  # The super admin is unaffected either way: SuperAdmin::ApplicationController descends
  # from Administrate's and SuperAdmin::Devise::SessionsController from Devise's, never
  # from this class, so its cookie-session CSRF protection stays on.
  skip_before_action :verify_authenticity_token, if: -> { request.path.start_with?('/api/') || devise_controller? }

  before_action :set_current_user, unless: :devise_controller?
  around_action :switch_locale
  around_action :handle_with_exception, unless: :devise_controller?

  private

  def set_current_user
    @user ||= current_user
    Current.user = @user
  end

  def pundit_user
    {
      user: Current.user,
      account: Current.account,
      account_user: Current.account_user
    }
  end
end
ApplicationController.include_mod_with('Concerns::ApplicationControllerConcern')
