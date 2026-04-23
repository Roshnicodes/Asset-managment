require "test_helper"

class PasswordResetFlowTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper
  self.fixture_table_names = []

  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "sending reset instructions works with mixed-case email input" do
    user = User.create!(
      email: "reset.user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_emails 1 do
      post user_password_path, params: { user: { email: "  RESET.User@Example.com  " } }
    end

    assert_redirected_to new_user_session_path

    user.reload
    assert_not_nil user.reset_password_token
    assert_not_nil user.reset_password_sent_at
    assert_includes ActionMailer::Base.deliveries.last.body.encoded, "reset_password_token="
  end
end
