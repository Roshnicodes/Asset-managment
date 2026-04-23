require "test_helper"

class UserTest < ActiveSupport::TestCase
  self.fixture_table_names = []

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
      email_id: "admin.employee@example.com",
      user_type: "Admin",
      stakeholder_category: stakeholder_category
    )

    provisioned_user = User.find_by!(email: employee_master.email_id)

    assert provisioned_user.admin?
  end
end
