require "test_helper"

class UserRegistrationFlowTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "public sign up is disabled" do
    assert_no_difference("User.count") do
      post user_registration_path, params: {
        user: {
          email: "signup.user@example.com",
          role: "user",
          password: "password12",
          password_confirmation: "password12"
        }
      }
    end

    assert_redirected_to new_user_session_path
    assert_equal "Sign up is not available.", flash[:alert]
  end
end
