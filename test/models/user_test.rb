require "test_helper"

class UserTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "role enum is backed by a declared attribute type" do
    assert User.attribute_types["role"]
    assert_equal({ "user" => 0, "admin" => 1 }, User.roles)
  end

  test "normalizes email and defaults role to user" do
    user = User.create!(
      email: "  Mixed.Case@example.com  ",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_equal "mixed.case@example.com", user.email
    assert_equal "user", user.role
  end

  test "admin role requires a matching admin employee master record" do
    user = User.new(
      email: "admin.candidate@example.com",
      role: :admin,
      password: "password123",
      password_confirmation: "password123"
    )

    assert_not user.valid?
    assert_includes user.errors[:role], "can be Admin only when the email belongs to an Admin employee master record"
  end

  test "employee login provisioning syncs the admin role" do
    stakeholder_category = StakeholderCategory.create!(name: "Internal Team")

    employee_master = EmployeeMaster.create!(
      name: "Admin Employee",
      employee_code: "ADM001",
      email_id: "admin.employee@example.com",
      user_type: "Admin",
      stakeholder_category: stakeholder_category
    )

    provisioned_user = User.find_by!(email: employee_master.email_id)

    assert provisioned_user.admin?
  end

  test "database authentication finds user by employee code" do
    stakeholder_category = StakeholderCategory.create!(name: "Login Team")
    employee_master = EmployeeMaster.create!(
      name: "Login Employee",
      employee_code: "emp-login",
      email_id: "login.employee@example.com",
      user_type: "User",
      stakeholder_category: stakeholder_category
    )

    user = User.find_for_database_authentication(email: "EMP-LOGIN")

    assert_equal employee_master.email_id, user.email
  end

  test "database authentication does not accept email as login id" do
    User.create!(
      email: "email.login@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_nil User.find_for_database_authentication(email: "email.login@example.com")
  end
end
