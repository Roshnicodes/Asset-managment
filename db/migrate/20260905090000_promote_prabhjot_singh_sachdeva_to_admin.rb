class PromotePrabhjotSinghSachdevaToAdmin < ActiveRecord::Migration[8.1]
  EMPLOYEE_CODE = "1621".freeze
  EMPLOYEE_NAME = "Prabhjot Singh Sachdeva".freeze

  def up
    require Rails.root.join("app/services/employee_login_provisioner")

    employee = EmployeeMaster.find_by("UPPER(TRIM(employee_code)) = ?", EMPLOYEE_CODE)
    return say("Employee code #{EMPLOYEE_CODE} not found; no admin role was changed.") unless employee

    unless employee.name.to_s.strip.casecmp(EMPLOYEE_NAME).zero?
      return say("Employee code #{EMPLOYEE_CODE} belongs to #{employee.name}; no admin role was changed.")
    end

    employee.update_columns(user_type: "Admin", updated_at: Time.current)
    EmployeeLoginProvisioner.provision_for!(employee)
  end

  def down
    say "Prabhjot Singh Sachdeva admin promotion is intentionally not reverted."
  end
end
