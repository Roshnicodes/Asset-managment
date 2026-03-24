class ApplicationController < ActionController::Base
  include ApprovalRequestsHelper
  before_action :authenticate_user!, unless: :devise_controller?
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_employee_master
  helper_method :unread_notifications_count

  def current_employee_master
    current_user&.employee_master
  end

  def unread_notifications_count
    return 0 unless current_user

    current_user.notifications.where(status: "unread").count
  end
end
