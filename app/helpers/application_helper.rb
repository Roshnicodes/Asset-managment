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
    logout: '<path d="M10 6H7a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h3"/><path d="M14 16l4-4-4-4"/><path d="M18 12h-8"/>',
    eye: '<path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    pencil: '<path d="M17 3a2.828 2.828 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z"/>',
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

  def can_view_menu?(identifier)
    return true if identifier.nil?
    return true if current_user.email == "admin@example.com"
    employee = current_user.employee_master
    return true unless employee
    
    role_perms = MenuPermission.where(stakeholder_category_id: employee.stakeholder_category_id, designation: employee.designation)
    return true if role_perms.empty?
    
    perm = role_perms.find_by(menu_identifier: identifier)
    perm ? perm.can_view? : false
  end

  def notification_target_path(notification)
    approval_request = notification.notifiable if notification.notifiable.is_a?(ApprovalRequest)
    approvable = approval_request&.approvable

    return vendor_registration_path(approvable) if approvable.is_a?(VendorRegistration)

    approval_requests_path
  end
end
