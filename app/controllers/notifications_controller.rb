class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.order(created_at: :desc)
    current_user.notifications.where(status: "unread").update_all(status: "read")
  end
end
