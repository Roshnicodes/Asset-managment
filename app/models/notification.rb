class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  STATUSES = %w[unread read].freeze

  validates :title, :status, presence: true
  validates :status, inclusion: { in: STATUSES }
end
