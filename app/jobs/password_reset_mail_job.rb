# Emails a password reset link through krai (the server has no SMTP). Runs in
# the app process (:async) like NotificationMailJob, because krai can take
# ~30 seconds to answer and the user should not wait for it.
class PasswordResetMailJob < ApplicationJob
  self.queue_adapter = :async unless Rails.env.test?

  def perform(user_id, reset_link)
    user = User.find_by(id: user_id)
    return unless user

    NotificationMailRelay.deliver_message!(
      kind: "password_reset",
      to_email: user.email,
      to_name: user.employee_master&.name.presence || user.email,
      subject: "Apurti - Reset your password",
      message: "A password reset was requested for your Apurti login (employee code #{user.employee_master&.employee_code}). " \
               "Open the link to set a new password. The link works for #{Devise.reset_password_within.inspect}. " \
               "If you did not ask for this, ignore this mail; your password stays the same.",
      link: reset_link
    )
  rescue StandardError => error
    Rails.logger.error("PasswordResetMailJob failed user=#{user_id}: #{error.class} #{error.message}")
  end
end
