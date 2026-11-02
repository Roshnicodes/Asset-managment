class Users::PasswordsController < Devise::PasswordsController
  def create
    if direct_password_reset_enabled?
      employee_code = resource_params[:email].to_s.strip
      employee = EmployeeMaster.find_by("LOWER(TRIM(employee_code)) = ?", employee_code.downcase)
      user = if employee&.email_id.present?
        User.find_by("LOWER(TRIM(email)) = ?", employee.email_id.to_s.strip.downcase)
      end

      if user.present?
        raw_token = set_reset_password_token_for(user)
        redirect_to edit_user_password_path(reset_password_token: raw_token), notice: "Reset link opened. Set a new password now."
      else
        self.resource = resource_class.new
        resource.email = employee_code
        resource.errors.add(:email, "employee code was not found")
        render :new, status: :unprocessable_entity
      end
    elsif NotificationMailRelay.enabled?
      send_reset_link_by_mail
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

  # Production has no SMTP: the reset link goes to the employee's registered
  # email through krai, like the notification mails.
  def send_reset_link_by_mail
    employee_code = resource_params[:email].to_s.strip
    employee = EmployeeMaster.find_by("LOWER(TRIM(employee_code)) = ?", employee_code.downcase) if employee_code.present?
    user = User.find_by("LOWER(TRIM(email)) = ?", employee.email_id.to_s.strip.downcase) if employee&.email_id.present?

    unless user&.email.to_s.include?("@")
      self.resource = resource_class.new
      resource.email = employee_code
      resource.errors.add(:base, "No login with a registered email was found for this employee code. Please contact the admin.")
      render :new, status: :unprocessable_entity
      return
    end

    raw_token = set_reset_password_token_for(user)
    PasswordResetMailJob.perform_later(user.id, edit_user_password_url(reset_password_token: raw_token))
    redirect_to new_user_session_path,
                notice: "A password reset link has been sent to #{masked_email(user.email)}. It may take a minute to arrive and works for #{Devise.reset_password_within.inspect}."
  end

  def masked_email(email)
    name, domain = email.to_s.split("@", 2)
    "#{name.to_s.first(2)}#{'*' * [name.to_s.length - 2, 3].max}@#{domain}"
  end

  def set_reset_password_token_for(user)
    raw_token, encrypted_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update!(
      reset_password_token: encrypted_token,
      reset_password_sent_at: Time.current
    )
    raw_token
  end
end
