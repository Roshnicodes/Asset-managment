# Emails a copy of one notification. Runs in the app process (:async) because
# the server does not run a separate job worker; a failed mail never affects
# the action that created the notification.
class NotificationMailJob < ApplicationJob
  self.queue_adapter = :async unless Rails.env.test?

  # Short-lived processes (the 9 AM reminder runs through `rails runner`) end
  # before a background thread could send; inside this block mails go at once.
  def self.inline
    previous = Thread.current[:notification_mail_inline]
    Thread.current[:notification_mail_inline] = true
    yield
  ensure
    Thread.current[:notification_mail_inline] = previous
  end

  def self.inline?
    Thread.current[:notification_mail_inline] == true
  end

  def perform(notification_id, mail_kind = nil)
    notification = Notification.includes(user: []).find_by(id: notification_id)
    return unless notification && NotificationMailRelay.enabled?

    notification.mail_kind = mail_kind
    NotificationMailRelay.deliver!(notification)
  rescue StandardError => error
    Rails.logger.error("NotificationMailRelay failed notification=#{notification_id}: #{error.class} #{error.message}")
  end
end
