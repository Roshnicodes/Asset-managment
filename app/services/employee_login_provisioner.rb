class EmployeeLoginProvisioner
  DEFAULT_PASSWORD = "Welcome@123".freeze

  def self.provision_for!(employee_master)
    return nil if employee_master.email_id.blank?

    user = User.find_or_initialize_by(email: employee_master.email_id.strip.downcase)

    if user.new_record?
      user.password = DEFAULT_PASSWORD
      user.password_confirmation = DEFAULT_PASSWORD
      user.save!
    end

    user
  end
end
