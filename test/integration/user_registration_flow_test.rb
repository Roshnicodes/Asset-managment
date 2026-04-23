require "test_helper"

class UserRegistrationFlowTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "sign up stores the selected user role" do
    assert_difference("User.count", 1) do
      post user_registration_path, params: {
        user: {
          email: "signup.user@example.com",
          role: "user",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    created_user = User.find_by!(email: "signup.user@example.com")

    assert_equal "user", created_user.role
    assert_redirected_to root_path
  end
end
