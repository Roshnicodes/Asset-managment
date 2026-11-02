class Users::RegistrationsController < Devise::RegistrationsController
  before_action :redirect_public_signup, only: %i[new create]

  protected

  # The login email is tied to the Employee Master (login is by employee code),
  # so here only the password can be changed.
  def account_update_params
    super.except(:email)
  end

  def after_update_path_for(_resource)
    root_path
  end

  private

  def redirect_public_signup
    redirect_to new_user_session_path, alert: "Sign up is not available."
  end
end
