class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  STATUSES = %w[unread read].freeze

  validates :title, :status, presence: true
  validates :status, inclusion: { in: STATUSES }

  # Which krai email page sends this notification (see NotificationMailRelay::PAGES).
  # Only used while creating; not stored.
  attr_accessor :mail_kind

  # Every notification is also emailed (through krai) once that is switched on.
  after_create_commit :send_email_copy

  private

  def send_email_copy
    return unless NotificationMailRelay.enabled?

    NotificationMailJob.inline? ? NotificationMailJob.perform_now(id, mail_kind) : NotificationMailJob.perform_later(id, mail_kind)
  rescue StandardError => error
    Rails.logger.error("NotificationMailJob could not be queued for notification=#{id}: #{error.message}")
  end
end
