class Users::PasswordsController < Devise::PasswordsController
  protected

  def resource_params
    permitted_attributes =
      if action_name == "create"
        [:email]
      else
        [:reset_password_token, :password, :password_confirmation]
      end

    params.fetch(resource_name, {}).permit(*permitted_attributes)
  end

  def after_resetting_password_path_for(resource)
    root_path # Redirect to dashboard after successful reset
  end
end
