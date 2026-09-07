require "test_helper"

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  self.fixture_table_names = []

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "direct reset opens reset form with mixed-case employee code input" do
    stakeholder_category = StakeholderCategory.create!(name: "Reset Team")
    EmployeeMaster.create!(
      name: "Reset User",
      employee_code: "RST001",
      email_id: "reset.user@example.com",
      user_type: "User",
      stakeholder_category: stakeholder_category
    )
    user = User.find_by!(email: "reset.user@example.com")

    assert_no_emails do
      with_direct_password_reset do
        post user_password_path, params: { user: { email: "  rst001  " } }
      end
    end

    assert_response :redirect
    assert_match %r{/users/password/edit\?reset_password_token=}, response.location

    user.reload
    assert_not_nil user.reset_password_token
    assert_not_nil user.reset_password_sent_at
  end

  private

  def with_direct_password_reset
    previous_value = ENV["DIRECT_PASSWORD_RESET"]
    ENV["DIRECT_PASSWORD_RESET"] = "true"
    yield
  ensure
    if previous_value.nil?
      ENV.delete("DIRECT_PASSWORD_RESET")
    else
      ENV["DIRECT_PASSWORD_RESET"] = previous_value
    end
  end
end
