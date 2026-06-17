class Users::SessionsController < Devise::SessionsController
  def destroy
    signed_out = Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
    reset_session
    set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    respond_to_on_destroy
  end
end
