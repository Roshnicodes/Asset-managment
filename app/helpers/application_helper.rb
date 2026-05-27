module ApplicationHelper
  APP_SVG_ICONS = {
    brand: '<path d="M7 8a3 3 0 0 1 3-3h6.2L21 9.8V19a3 3 0 0 1-3 3H10a3 3 0 0 1-3-3V8Z"/><path d="M16.2 5v3.2A1.8 1.8 0 0 0 18 10h3"/><path d="M11 13h6"/><path d="M11 17h4"/>',
    dashboard: '<path d="M4 12.5 12 5l8 7.5"/><path d="M6.5 10.5V20h11V10.5"/><path d="M10 20v-5h4v5"/>',
    office: '<rect x="4" y="6" width="16" height="14" rx="2"/><path d="M8 10h8"/><path d="M8 14h3"/><path d="M14 14h2"/><path d="M8 18h8"/>',
    map: '<path d="M9 5 4 7v12l5-2 6 2 5-2V5l-5 2-6-2Z"/><path d="M9 5v12"/><path d="M15 7v12"/>',
    people: '<path d="M8 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z"/><path d="M16.5 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Z"/><path d="M3.5 19a4.5 4.5 0 0 1 9 0"/><path d="M14 19a3.5 3.5 0 0 1 7 0"/>',
    registration: '<path d="M7 4h8l4 4v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M15 4v4h4"/><path d="M9 12h6"/><path d="M9 16h6"/>',
    service: '<path d="M14 6 18 10"/><path d="M8 18 4 14"/><path d="m10 14 4-4"/><path d="M6 8h4v4H6z"/><path d="M14 12h4v4h-4z"/>',
    theme: '<path d="M12 4c4.5 0 8 3 8 7.5S16.5 20 12 20s-8-4-8-8.5S7.5 4 12 4Z"/><path d="M12 4c-1 3.2-.8 6 0 8.5 1.2 3.6 3.7 5.7 8 6.2"/><path d="M4.5 14h6.2"/>',
    product: '<rect x="5" y="7" width="14" height="12" rx="2"/><path d="M9 7V5h6v2"/><path d="M8.5 11h7"/><path d="M8.5 15h4"/>',
    layers: '<path d="m12 4 8 4-8 4-8-4 8-4Z"/><path d="m4 12 8 4 8-4"/><path d="m4 16 8 4 8-4"/>',
    unit: '<path d="M5 18 18 5"/><path d="M7 7h4v4"/><path d="M13 13h4v4"/>',
    document: '<path d="M7 4h8l4 4v10a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M15 4v4h4"/><path d="M9 13h6"/><path d="M9 17h4"/>',
    approval: '<path d="M12 3 4 7v5c0 5 3.4 8.5 8 10 4.6-1.5 8-5 8-10V7l-8-4Z"/><path d="m9 12 2 2 4-4"/>',
    firm: '<path d="M4 20V8l8-4 8 4v12"/><path d="M8 20v-5h8v5"/><path d="M8 10h2"/><path d="M14 10h2"/>',
    bank: '<path d="M3 10 12 5l9 5"/><path d="M5 10v8"/><path d="M9 10v8"/><path d="M15 10v8"/><path d="M19 10v8"/><path d="M3 20h18"/>',
    vendor: '<path d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z"/><path d="M5 20a7 7 0 0 1 14 0"/><path d="M18 8h3"/><path d="M19.5 6.5v3"/>',
    asset: '<rect x="5" y="5" width="14" height="14" rx="3"/><path d="M9 9h6v6H9z"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="M2 12h3"/><path d="M19 12h3"/>',
    allocation: '<path d="M5 7h8a3 3 0 0 1 0 6H7"/><path d="M11 17H5a3 3 0 0 1 0-6h2"/><path d="m13 14 3 3 4-4"/>',
    insurance: '<path d="M12 3 5 6.5V12c0 4.6 2.8 8.2 7 9.8 4.2-1.6 7-5.2 7-9.8V6.5L12 3Z"/><path d="M9 12h6"/><path d="M12 9v6"/>',
    logout: '<path d="M10 6H7a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h3"/><path d="M14 16l4-4-4-4"/><path d="M18 12h-8"/>',
    eye: '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    pencil: '<path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>',
    key: '<circle cx="7.5" cy="14.5" r="3.5"/><path d="M10 12 21 1"/><path d="M16 6h4v4"/><path d="M14 8l3 3"/>',
    trash: '<polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/>'
  }.freeze

  def app_icon(name, classes: "app-menu-icon", size: 24)
    path = APP_SVG_ICONS.fetch(name.to_sym)
    content_tag(:svg, path.html_safe, class: classes, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor",
      width: size, height: size,
      "stroke-width": "2.2", "stroke-linecap": "round", "stroke-linejoin": "round", aria: { hidden: true })
  end

  def app_nav_link(label, path, icon:, identifier: nil, class_name: "nav-link")
    return unless can_view_menu?(identifier)

    link_to path, class: class_name do
      content_tag(:span, class: "app-link-wrap") do
        safe_join([app_icon(icon), content_tag(:span, label, class: "app-link-label")])
      end
    end
  end

  def app_dropdown_toggle(label, target_id, icon:, identifier: nil)
    return unless can_view_menu?(identifier)

    content_tag(:a, class: "nav-link dropdown-toggle-link", data: { bs_toggle: "collapse" }, href: "##{target_id}") do
      safe_join([content_tag(:span, safe_join([app_icon(icon), content_tag(:span, label, class: "app-link-label")]), class: "app-link-wrap")])
    end
  end

  def catalog_item_option_label(item)
    return item.to_s if item.is_a?(String)

    case item
    when Product
      [item.product_code.presence, item.name.presence].compact.join(" | ")
    when ProductVariety
      base_label = [item.product_type_code.presence, item.name.presence].compact.join(" | ")
      product_name = item.product&.name.to_s.strip
      product_name.present? ? "#{base_label} (#{product_name})" : base_label
    else
      item.to_s
    end
  end

  def quotation_item_product_type_code(item_name)
    normalized_name = item_name.to_s.strip
    return nil if normalized_name.blank?

    quotation_catalog_product_types_by_name[normalized_name]&.product_type_code.to_s.strip.presence
  end

  def asset_product_code_label(product)
    return "" if product.blank?

    product.asset_product_type_code_segment
  end

  def quotation_item_display_name(item_name)
    normalized_name = item_name.to_s.strip
    return "-" if normalized_name.blank?

    matched_product = quotation_catalog_products_by_name[normalized_name]
    return catalog_item_option_label(matched_product) if matched_product.present?

    matched_product_type = quotation_catalog_product_types_by_name[normalized_name]
    return catalog_item_option_label(matched_product_type) if matched_product_type.present?

    normalized_name
  end

  def current_stakeholder_category
    current_employee_master&.stakeholder_category
  end

  def stakeholder_logo_source(stakeholder = current_stakeholder_category, fallback: "asset-logoq.svg")
    return fallback if stakeholder.blank?

    if stakeholder.respond_to?(:logo_file) && stakeholder.logo_file.attached?
      rails_blob_path(stakeholder.logo_file, only_path: true)
    elsif stakeholder.respond_to?(:logo_url) && stakeholder.logo_url.present?
      stakeholder.logo_url
    else
      fallback
    end
  end

  def navbar_logo_source
    stakeholder_logo_source
  end

  def stakeholder_logo_alt(stakeholder = current_stakeholder_category, fallback: "Company Logo")
    stakeholder_name = stakeholder&.name.to_s.strip
    stakeholder_name.present? ? "#{stakeholder_name} Logo" : fallback
  end

  def navbar_logo_alt
    stakeholder_logo_alt
  end

  def can_view_menu?(identifier)
    return true if identifier.nil?
    return true if identifier == "dashboard"
    return true if admin_user?
    return finance_queue_access? if identifier == "payment_advice_queue"
    
    employee = current_employee_master
    return false unless employee
    
    # If User Type is User, check permissions
    role_perms = MenuPermission.where(stakeholder_category_id: employee.stakeholder_category_id, designation: employee.designation)
    return false if role_perms.empty? # By default, when new employee logs in, nothing is visible

    if identifier == "office_category_main"
      office_menu_ids = %w[office_category_master office_category_name office_pmu office_fco office_to]
      return true if role_perms.where(menu_identifier: office_menu_ids, can_view: true).exists?
    end

    if identifier == "office_category_master"
      return true if role_perms.where(menu_identifier: %w[office_category_master office_pmu office_fco office_to], can_view: true).exists?
    end

    if identifier == "office_category_name"
      return true if role_perms.where(menu_identifier: %w[office_category_name office_pmu office_fco office_to], can_view: true).exists?
    end

    if identifier == "vendor_registration_main"
      return true if role_perms.find_by(menu_identifier: "vendor_registration")&.can_view?
      return true if role_perms.find_by(menu_identifier: "vendor_registration_list")&.can_view?
    end

    if identifier == "quotation_proposal_main"
      return true if role_perms.find_by(menu_identifier: "quotation_proposal_form")&.can_view?
      return true if role_perms.find_by(menu_identifier: "quotation_proposal_list")&.can_view?
      return true if finance_queue_access?
    end

    if identifier == "assets"
      return true if role_perms.find_by(menu_identifier: "assets")&.can_view?
      return true if role_perms.find_by(menu_identifier: "quotation_proposal_form")&.can_view?
      return true if role_perms.find_by(menu_identifier: "quotation_proposal_list")&.can_view?
    end
    
    perm = role_perms.find_by(menu_identifier: identifier)
    perm ? perm.can_view? : false
  end

  def notification_target_path(notification)
    approval_request = notification.notifiable if notification.notifiable.is_a?(ApprovalRequest)
    approvable = approval_request&.approvable

    return approval_record_target_path(approvable) if approvable.present?

    approval_requests_path
  end

  def approval_record_target_path(approvable)
    return approval_requests_path unless approvable.respond_to?(:user_id)
    return vendor_registration_path(approvable) if approvable.is_a?(VendorRegistration) && can_view_approvable_record?(approvable)
    return quotation_proposal_path(approvable) if approvable.is_a?(QuotationProposal) && can_view_approvable_record?(approvable)

    approval_requests_path
  end

  def can_view_approvable_record?(approvable)
    return false unless approvable
    return true if admin_user?
    return true if approvable.user_id == current_user.id
    return false unless approvable.respond_to?(:approval_request)

    approvable.approval_request&.approval_steps&.any? do |step|
      employee_matches_current_login?(step.employee_master)
    end || false
  end

  def approval_status_badge_data(approval_request)
    return { label: "Not Started", css_class: "bg-secondary bg-opacity-10 text-secondary border-secondary" } unless approval_request

    viewer_steps = viewer_approval_steps_for(approval_request)
    if !admin_user? && viewer_steps.any?
      return {
        label: viewer_approval_status_summary(approval_request),
        css_class: viewer_approval_status_css_class(approval_request)
      }
    end

    {
      label: approval_request.status_label,
      css_class: approval_request_overall_css_class(approval_request)
    }
  end

  def viewer_approval_steps_for(approval_request)
    return [] unless approval_request
    return [] unless current_approval_employee_ids.any?

    approval_request.approval_steps.select do |step|
      employee_matches_current_login?(step.employee_master) && !step.proposal_create_step?
    end.sort_by(&:level)
  end

  def viewer_approval_status_summary(approval_request)
    viewer_approval_steps_for(approval_request).map do |step|
      "#{WorkflowLevelNaming.humanize_level_label(step.level)} #{step.effective_status_label}"
    end.join(", ")
  end

  def viewer_approval_status_css_class(approval_request)
    statuses = viewer_approval_steps_for(approval_request).map(&:effective_status)

    if statuses.include?("rejected")
      approval_status_css_class_for("rejected")
    elsif statuses.include?("returned")
      approval_status_css_class_for("returned")
    elsif statuses.include?("pending")
      approval_status_css_class_for("pending")
    elsif statuses.present? && statuses.all? { |status| status == "approved" }
      approval_status_css_class_for("approved")
    else
      approval_status_css_class_for(nil)
    end
  end

  def approval_status_css_class_for(status)
    case status.to_s
    when "approved"
      "bg-success bg-opacity-10 text-success border-success"
    when "returned"
      "bg-warning bg-opacity-10 text-warning border-warning"
    when "rejected"
      "bg-danger bg-opacity-10 text-danger border-danger"
    when "pending"
      "bg-info bg-opacity-10 text-info border-info"
    else
      "bg-secondary bg-opacity-10 text-secondary border-secondary"
    end
  end

  def approval_request_overall_css_class(approval_request)
    return "bg-warning bg-opacity-10 text-warning border-warning" if approval_request.employee_return_pending? || approval_request.level_return_pending?

    approval_status_css_class_for(approval_request.status)
  end

  private

  def quotation_catalog_products
    products = instance_variable_defined?(:@products) ? instance_variable_get(:@products) : nil
    products.presence || Product.order(:name).to_a
  end

  def quotation_catalog_product_types
    product_types = instance_variable_defined?(:@product_varieties) ? instance_variable_get(:@product_varieties) : nil
    product_types.presence || ProductVariety.includes(:product).order(:name).to_a
  end

  def quotation_catalog_products_by_name
    @quotation_catalog_products_by_name ||= quotation_catalog_products.index_by { |product| product.name.to_s.strip }
  end

  def quotation_catalog_product_types_by_name
    @quotation_catalog_product_types_by_name ||= quotation_catalog_product_types.index_by { |product_type| product_type.name.to_s.strip }
  end
end
