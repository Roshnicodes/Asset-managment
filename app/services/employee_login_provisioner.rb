class EmployeeLoginProvisioner
  DEFAULT_PASSWORD = "Welcome@123".freeze

  def self.provision_for!(employee_master, password: nil, password_confirmation: nil)
    return nil if employee_master.email_id.blank?

    user = User.find_or_initialize_by(email: employee_master.email_id.strip.downcase)
    chosen_password = password.presence || DEFAULT_PASSWORD
    chosen_confirmation = password_confirmation.presence || chosen_password

    if user.new_record? || password.present?
      user.password = chosen_password
      user.password_confirmation = chosen_confirmation
      user.save!
    end

    user
  end
end
