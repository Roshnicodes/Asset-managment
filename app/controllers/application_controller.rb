class ApplicationController < ActionController::Base
  include ApprovalRequestsHelper
  helper QrCodesHelper
  before_action :authenticate_user!, unless: :devise_controller?
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_employee_master
  helper_method :unread_notifications_count
  helper_method :admin_user?
  helper_method :current_login_email
  helper_method :current_approval_employee_ids
  helper_method :approval_actor_for
  helper_method :employee_matches_current_login?

  def current_employee_master
    return @current_employee_master if defined?(@current_employee_master)

    lookup_email = current_user&.email.to_s.strip.downcase
    @current_employee_master =
      if lookup_email.present?
        current_user&.employee_master || EmployeeMaster.find_by("LOWER(TRIM(email_id)) = ?", lookup_email)
      end
  end

  def unread_notifications_count
    return 0 unless current_user

    current_user.notifications.where(status: "unread").count
  end

  def current_login_email
    current_user&.email.to_s.strip.downcase
  end

  def admin_user?
    return false unless current_user

    current_user.email == "admin@example.com" || current_employee_master&.user_type == "Admin"
  end

  def current_approval_employee_ids
    return @current_approval_employee_ids if defined?(@current_approval_employee_ids)

    ids =
      if current_employee_master.present?
        [current_employee_master.id]
      elsif current_login_email.present?
        EmployeeMaster.where("LOWER(TRIM(email_id)) = ?", current_login_email).pluck(:id)
      else
        []
      end

    @current_approval_employee_ids = ids.compact.uniq
  end

  def employee_matches_current_login?(employee)
    return false unless employee

    if current_employee_master.present?
      employee.id == current_employee_master.id
    else
      current_approval_employee_ids.include?(employee.id) ||
        employee.email_id.to_s.strip.downcase == current_login_email
    end
  end

  def approval_actor_for(record = nil)
    case record
    when ApprovalRequest
      matched_step = record.approval_steps.includes(:employee_master).detect do |step|
        employee_matches_current_login?(step.employee_master)
      end
      return matched_step.employee_master if matched_step.present?
    when QuotationProposal
      step_scope = record.approval_request.present? ? record.approval_request.approval_steps.includes(:employee_master) : record.committee_steps.includes(:employee_master)
      matched_step = step_scope.detect do |step|
        employee_matches_current_login?(step.employee_master)
      end
      return matched_step.employee_master if matched_step&.employee_master.present?
    end

    return current_employee_master if current_employee_master.present?
    return if current_login_email.blank?

    case record
    when ApprovalRequest
      record.approval_steps.includes(:employee_master).map(&:employee_master).find do |employee|
        employee&.email_id.to_s.strip.downcase == current_login_email
      end
    when QuotationProposal
      step_scope = record.approval_request.present? ? record.approval_request.approval_steps.includes(:employee_master) : record.committee_steps.includes(:employee_master)
      step_scope.map(&:employee_master).find do |employee|
        employee&.email_id.to_s.strip.downcase == current_login_email
      end
    else
      EmployeeMaster.find_by("LOWER(TRIM(email_id)) = ?", current_login_email)
    end
  end
end
