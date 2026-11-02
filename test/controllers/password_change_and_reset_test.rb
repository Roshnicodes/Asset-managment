require "test_helper"

# Users can change their password inside Apurti, and reset it from the login
# page: the reset link is mailed through krai because the server has no SMTP.
class PasswordChangeAndResetTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  self.fixture_table_names = []

  setup do
    stakeholder = StakeholderCategory.create!(name: "Password Stakeholder")
    @employee = EmployeeMaster.create!(designation: "Officer", employee_code: "PW-001", email_id: "pw.user@example.com",
                                       name: "Password User", stakeholder_category: stakeholder, user_type: "User")
    @user = User.find_by!(email: @employee.email_id)
    @user.update!(password: "Old@1234", password_confirmation: "Old@1234")
  end

  test "the login page offers Forgot Password" do
    get new_user_session_path
    assert_response :success
    assert_select "a[href=?]", new_user_password_path, text: "Forgot Password?"
  end

  test "a reset link is mailed through krai for the employee code" do
    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/", "DIRECT_PASSWORD_RESET" => "false") do
      Rails.env.stub(:development?, false) do
        assert_enqueued_with(job: PasswordResetMailJob) do
          post user_password_path, params: { user: { email: "pw-001" } }
        end
      end
    end

    assert_redirected_to new_user_session_path
    assert_match "pw*****@example.com", flash[:notice]
    assert @user.reload.reset_password_token.present?

    link = enqueued_jobs.last[:args].last
    assert_match %r{/users/password/edit\?reset_password_token=}, link
  end

  test "the mail job sends the link to the user's email through krai" do
    sent = nil
    ok = Struct.new(:code, :body) { def is_a?(klass) = klass == Net::HTTPSuccess || super }.new("200", "OK")

    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/") do
      PaymentAdviceMailRelay.stub(:get, ->(uri) { sent = uri; ok }) do
        PasswordResetMailJob.perform_now(@user.id, "https://apurti.asaindia.org/users/password/edit?reset_password_token=abc")
      end
    end

    query = URI.decode_www_form(sent.query).to_h
    assert_equal "/apurti_nnotify.aspx", sent.path
    assert_equal "pw.user@example.com", query["to_email"]
    assert_equal "Password User", query["to_name"]
    assert_equal "https://apurti.asaindia.org/users/password/edit?reset_password_token=abc", query["link"]
  end

  test "an unknown employee code is reported and nothing is sent" do
    with_env("NOTIFICATION_MAIL_RELAY_URL" => "https://krai.asaindia.org/", "DIRECT_PASSWORD_RESET" => "false") do
      Rails.env.stub(:development?, false) do
        assert_no_enqueued_jobs(only: PasswordResetMailJob) do
          post user_password_path, params: { user: { email: "NOPE-999" } }
        end
      end
    end

    assert_response :unprocessable_entity
    assert_match "No login with a registered email", response.body
  end

  test "a signed-in user changes the password but not the login email" do
    sign_in @user

    get edit_user_registration_path
    assert_response :success

    put user_registration_path, params: { user: { email: "changed@example.com", password: "New@4567",
                                                  password_confirmation: "New@4567", current_password: "Old@1234" } }

    assert_redirected_to root_path
    @user.reload
    assert @user.valid_password?("New@4567")
    assert_equal "pw.user@example.com", @user.email
  end

  private

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
