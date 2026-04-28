class Users::RegistrationsController < Devise::RegistrationsController
  before_action :redirect_public_signup, only: %i[new create]

  private

  def redirect_public_signup
    redirect_to new_user_session_path, alert: "Sign up is not available."
  end
end
