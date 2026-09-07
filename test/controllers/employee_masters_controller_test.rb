require "test_helper"

class EmployeeMastersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  self.fixture_table_names = []

  setup do
    @stakeholder_category = StakeholderCategory.create!(name: "Employee Admin Test")
  end

  test "non admin employee creator cannot assign admin user type" do
    creator = create_employee(
      name: "Employee Creator",
      employee_code: "EMP-CREATOR",
      email_id: "employee.creator@example.com",
      designation: "Employee Creator",
      user_type: "User"
    )
    MenuPermission.create!(
      stakeholder_category: @stakeholder_category,
      designation: creator.designation,
      menu_identifier: "employee_master",
      can_view: true
    )

    sign_in User.find_by!(email: creator.email_id)

    assert_difference -> { EmployeeMaster.count }, 1 do
      post employee_masters_url, params: {
        employee_master: {
          stakeholder_category_id: @stakeholder_category.id,
          user_type: "Admin",
          employee_code: "EMP-REQUESTED-ADMIN",
          name: "Requested Admin",
          designation: "Staff",
          email_id: "requested.admin@example.com"
        }
      }
    end

    employee = EmployeeMaster.find_by!(employee_code: "EMP-REQUESTED-ADMIN")
    assert_redirected_to employee_masters_url
    assert_equal "User", employee.user_type
    assert_predicate User.find_by!(email: employee.email_id), :user?
  end

  test "admin can promote another employee to admin" do
    admin = create_employee(
      name: "Existing Admin",
      employee_code: "EMP-ADMIN",
      email_id: "existing.admin@example.com",
      user_type: "Admin"
    )
    employee = create_employee(
      name: "Future Admin",
      employee_code: "EMP-FUTURE-ADMIN",
      email_id: "future.admin@example.com",
      user_type: "User"
    )

    sign_in User.find_by!(email: admin.email_id)

    patch employee_master_url(employee), params: {
      employee_master: {
        user_type: "Admin"
      }
    }

    assert_redirected_to employee_masters_url
    assert_equal "Admin", employee.reload.user_type
    assert_predicate User.find_by!(email: employee.email_id), :admin?
  end

  private

  def create_employee(attributes)
    EmployeeMaster.create!(
      {
        stakeholder_category: @stakeholder_category,
        designation: "Staff"
      }.merge(attributes)
    )
  end
end
