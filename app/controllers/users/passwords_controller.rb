class Users::PasswordsController < Devise::PasswordsController
  def create
    if direct_password_reset_enabled?
      lookup_email = resource_params[:email].to_s.strip.downcase
      user = User.find_by("LOWER(TRIM(email)) = ?", lookup_email)

      if user.present?
        raw_token = user.send_reset_password_instructions
        redirect_to edit_user_password_path(reset_password_token: raw_token), notice: "Reset link opened. Set a new password now."
      else
        self.resource = resource_class.new
        resource.email = lookup_email
        resource.errors.add(:email, "was not found")
        render :new, status: :unprocessable_entity
      end
    else
      begin
        super
      rescue StandardError => e
        Rails.logger.error("Password reset delivery failed: #{e.class} - #{e.message}")
        self.resource = resource_class.new(resource_params)
        flash.now[:alert] = "Unable to send password reset instructions right now. Please try again later or contact support."
        render :new, status: :service_unavailable
      end
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

  def direct_password_reset_enabled?
    Rails.env.development? || ActiveModel::Type::Boolean.new.cast(ENV["DIRECT_PASSWORD_RESET"])
  end
end
