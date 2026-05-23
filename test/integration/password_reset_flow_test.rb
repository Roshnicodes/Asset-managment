require "test_helper"

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  self.fixture_table_names = []

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "sending reset instructions works with mixed-case employee code input" do
    stakeholder_category = StakeholderCategory.create!(name: "Reset Team")
    EmployeeMaster.create!(
      name: "Reset User",
      employee_code: "RST001",
      email_id: "reset.user@example.com",
      user_type: "User",
      stakeholder_category: stakeholder_category
    )
    user = User.create!(
      email: "reset.user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_emails 1 do
      post user_password_path, params: { user: { email: "  rst001  " } }
    end

    assert_redirected_to new_user_session_path

    user.reload
    assert_not_nil user.reset_password_token
    assert_not_nil user.reset_password_sent_at
    assert_includes ActionMailer::Base.deliveries.last.body.encoded, "reset_password_token="
  end
end
