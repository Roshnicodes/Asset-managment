class ApplicationController < ActionController::Base
  include ApprovalRequestsHelper
  helper QrCodesHelper
  helper QuotationVendorQrsHelper
  before_action :set_no_store_headers
  before_action :authenticate_user!, unless: :devise_controller?
  before_action :authorize_rbac_menu_access!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  allow_browser versions: :modern

  RBAC_MENU_BY_CONTROLLER = {
    "allocations" => "allocation",
    "approval_channels" => "approval_channels",
    "asset_insurances" => "assets",
    "assets" => "assets",
    "blocks" => "lg_block",
    "districts" => "lg_district",
    "document_masters" => "documents",
    "employee_masters" => "employee_master",
    "fcos" => "office_category_name",
    "firms" => "firms",
    "menu_permissions" => "rbac_master",
    "office_categories" => "office_category_name",
    "office_category_masters" => "office_category_master",
    "pmus" => "office_category_name",
    "product_varieties" => "product_varieties",
    "products" => "products",
    "quotation_proposals" => {
      "list" => "quotation_proposal_list",
      "payment_advice" => "payment_advice_queue",
      "update_payment_advice" => "payment_advice_queue",
      "default" => "quotation_proposal_form"
    },
    "registration_types" => "registration_types",
    "service_types" => "service_types",
    "stakeholder_categories" => "stakeholder_categories",
    "states" => "lg_state",
    "themes" => "vendor_themes",
    "tos" => "office_category_name",
    "units" => "units",
    "vendor_bank_masters" => "banks",
    "vendor_registration_invitations" => "vendor_registration",
    "vendor_registrations" => {
      "list" => "vendor_registration_list",
      "default" => "vendor_registration"
    },
    "vendor_selection_criteria" => "vendor_selection_criteria"
  }.freeze

  RBAC_ADMIN_ONLY_ACTIONS = %w[
    destroy destroy_selected edit import reset_login_password sync_logins update update_all
  ].freeze

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_employee_master
  helper_method :unread_notifications_count
  helper_method :admin_user?
  helper_method :current_login_email
  helper_method :current_approval_employee_ids
  helper_method :approval_actor_for
  helper_method :employee_matches_current_login?
  helper_method :finance_queue_access?
  helper_method :senior_manager_finance?
  helper_method :can_manage_rbac_menu_records?

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

    current_user.admin? || current_employee_master&.user_type == "Admin"
  end

  def current_approval_employee_ids
    return @current_approval_employee_ids if defined?(@current_approval_employee_ids)

    ids = []
    ids << current_employee_master.id if current_employee_master.present?
    if current_login_email.present?
      ids.concat(EmployeeMaster.where("LOWER(TRIM(email_id)) = ?", current_login_email).pluck(:id))
    end

    @current_approval_employee_ids = ids.compact.uniq
  end

  def employee_matches_current_login?(employee)
    return false unless employee

    current_approval_employee_ids.include?(employee.id) ||
      employee.email_id.to_s.strip.downcase == current_login_email
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

  def finance_queue_access?
    return true if admin_user?

    senior_manager_finance?
  end

  private

  def paginate_scope(scope, per_page: 10)
    page = params[:page].to_i
    page = 1 if page < 1

    total_count = scope.count
    total_pages = [(total_count.to_f / per_page).ceil, 1].max
    page = [page, total_pages].min

    offset = (page - 1) * per_page
    records = scope.limit(per_page).offset(offset)
    pagination = {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      from: total_count.zero? ? 0 : offset + 1,
      to: [offset + per_page, total_count].min
    }

    [records, pagination]
  end

  def search_query
    params[:q].to_s.strip
  end

  def search_pattern
    "%#{ActiveRecord::Base.sanitize_sql_like(search_query.downcase)}%"
  end

  def set_no_store_headers
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"
  end

  def authorize_rbac_menu_access!
    return unless current_user

    menu_identifier = rbac_menu_identifier_for_current_request
    return if menu_identifier.blank?
    return if admin_user?

    if controller_name == "menu_permissions" || RBAC_ADMIN_ONLY_ACTIONS.include?(action_name)
      redirect_to root_path, alert: "Only admin can edit or delete records."
      return
    end

    return if rbac_menu_access_allowed?(menu_identifier)

    redirect_to root_path, alert: "You are not authorized to access this page."
  end

  def rbac_menu_identifier_for_current_request
    mapping = RBAC_MENU_BY_CONTROLLER[controller_name]

    case mapping
    when Hash
      mapping[action_name] || mapping["default"]
    else
      mapping
    end
  end

  def rbac_menu_access_allowed?(identifier)
    return true if identifier.blank?
    return true if identifier == "dashboard"
    return finance_queue_access? if identifier == "payment_advice_queue"

    employee = current_employee_master
    return false unless employee

    role_permissions = MenuPermission.where(
      stakeholder_category_id: employee.stakeholder_category_id,
      designation: employee.designation
    )
    return false if role_permissions.empty?

    case identifier
    when "office_category_main"
      role_permissions.where(menu_identifier: %w[office_category_master office_category_name office_pmu office_fco office_to], can_view: true).exists?
    when "office_category_master"
      role_permissions.where(menu_identifier: %w[office_category_master office_pmu office_fco office_to], can_view: true).exists?
    when "office_category_name"
      role_permissions.where(menu_identifier: %w[office_category_name office_pmu office_fco office_to], can_view: true).exists?
    when "vendor_registration_main"
      role_permissions.where(menu_identifier: %w[vendor_registration vendor_registration_list], can_view: true).exists?
    when "quotation_proposal_main"
      role_permissions.where(menu_identifier: %w[quotation_proposal_form quotation_proposal_list], can_view: true).exists? || finance_queue_access?
    when "assets"
      role_permissions.where(menu_identifier: %w[assets quotation_proposal_form quotation_proposal_list], can_view: true).exists?
    else
      role_permissions.find_by(menu_identifier: identifier)&.can_view? || false
    end
  end

  def can_manage_rbac_menu_records?
    admin_user?
  end

  def senior_manager_finance?
    current_employee_master&.designation.to_s.strip.casecmp("Senior Manager Finance").zero?
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
  end
end
