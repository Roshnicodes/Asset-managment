class Users::SessionsController < Devise::SessionsController
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_invalid_authenticity_token

  def destroy
    signed_out = Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
    reset_session
    set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    respond_to_on_destroy
  end

  private

  def handle_invalid_authenticity_token
    reset_session
    redirect_to new_user_session_path, alert: "Your login session expired. Please refresh the page and sign in again."
  end
end
