# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

stakeholder = StakeholderCategory.find_or_create_by!(name: "Internal Team")

EmployeeMaster.find_or_initialize_by(employee_code: "EMP001").tap do |employee|
  employee.assign_attributes(
    stakeholder_category: stakeholder,
    user_type: "Admin",
    name: "Demo Admin",
    designation: "Administrator",
    email_id: "admin@example.com",
    mobile_no: "9999999999",
    password: EmployeeLoginProvisioner::DEFAULT_PASSWORD,
    password_confirmation: EmployeeLoginProvisioner::DEFAULT_PASSWORD
  )
  employee.save!
end
