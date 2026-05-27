class EmployeeLoginProvisioner
  DEFAULT_PASSWORD = "Welcome@1".freeze

  def self.provision_for!(employee_master, password: nil, password_confirmation: nil)
    return nil if employee_master.email_id.blank? || employee_master.employee_code.blank?

    user = User.find_or_initialize_by(email: employee_master.email_id.strip.downcase)
    chosen_password = password.presence || DEFAULT_PASSWORD
    chosen_confirmation = password_confirmation.presence || chosen_password
    target_role = employee_master.user_type.to_s.strip.downcase
    target_role = "user" unless User.roles.key?(target_role)
    role_changed = user.role.to_s != target_role

    user.role = target_role

    if user.new_record? || password.present?
      user.password = chosen_password
      user.password_confirmation = chosen_confirmation
    end

    user.save! if user.new_record? || password.present? || role_changed

    user
  end
end
