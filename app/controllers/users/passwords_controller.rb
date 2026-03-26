class Users::PasswordsController < Devise::PasswordsController
  def create
    self.resource = resource_class.find_by(email: resource_params[:email])
    
    if resource
      # Generate token manually to allow an "instant" reset experience
      raw_token, enc_token = Devise.token_generator.generate(resource.class, :reset_password_token)
      resource.reset_password_token = enc_token
      resource.reset_password_sent_at = Time.current
      resource.save(validate: false)

      # Immediate redirect to the "Set New Password" page with the token
      flash[:notice] = "Please choose a new password now."
      redirect_to edit_user_password_path(reset_password_token: raw_token)
    else
      self.resource = resource_class.new(resource_params)
      set_flash_message!(:alert, :not_found)
      render :new
    end
  end

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
