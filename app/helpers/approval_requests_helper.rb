module ApprovalRequestsHelper
  def pending_approvals_count(form_name = nil)
    scope = ApprovalRequest.where(status: "pending")
    scope = scope.where(form_name: form_name) if form_name.present?

    if admin_user?
      return scope.count
    end
    return 0 unless current_approval_employee_ids.any?
    
    scope.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_approval_employee_ids, status: "pending" })
      .distinct
      .count
  end

  def approved_approvals_count
    if admin_user?
      return ApprovalRequest.where(status: "approved").count
    end
    return 0 unless current_approval_employee_ids.any?
    
    ApprovalRequest.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_approval_employee_ids, status: "approved" })
      .where(status: "approved")
      .distinct
      .count
  end

  def rejected_approvals_count
    if admin_user?
      return ApprovalRequest.where(status: "rejected").count
    end
    return 0 unless current_approval_employee_ids.any?
    
    ApprovalRequest.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_approval_employee_ids, status: "rejected" })
      .where(status: "rejected")
      .distinct
      .count
  end

  def returned_approvals_count
    if admin_user?
      return ApprovalRequest.where(status: "returned").count
    end
    return 0 unless current_approval_employee_ids.any?

    ApprovalRequest.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_approval_employee_ids, status: "returned" })
      .where(status: "returned")
      .distinct
      .count
  end

  def total_approvals_count
    pending_approvals_count + approved_approvals_count + returned_approvals_count + rejected_approvals_count
  end

  # Display data for one row of the My Approvals table.
  def approval_row_info(approval_request)
    record = approval_request.approvable
    info = case record
           when VendorRegistration
             { icon: :people, tone: "green", code: format("VEN-%03d", record.id),
               title: record.vendor_name.presence || record.firm_name,
               subtitle: [record.stakeholder_category&.name, record.firm_type].compact_blank.join(" | ") }
           when QuotationProposal
             { icon: :document, tone: "purple", code: format("QTN-%03d", record.id),
               title: record.subject, subtitle: record.theme&.name }
           else
             { icon: :approval, tone: "orange", code: "#{approval_request.form_name.to_s.split.map(&:first).join.upcase}-#{format('%03d', approval_request.approvable_id)}",
               title: approval_request.reference_label, subtitle: approval_request.form_name }
           end

    pending = approval_request.approval_steps.select { |step| step.status == "pending" }.sort_by(&:level)
    shown = pending.presence || [approval_request.approval_steps.reject { |step| step.status.in?(%w[waiting pending]) }
                                                    .max_by { |step| [step.actioned_at || Time.at(0), step.level] }].compact
    info.merge(
      level: pending.any? ? approval_request.current_level_label : (shown.first ? WorkflowLevelNaming.humanize_level_label(shown.first.level) : "-"),
      approver: shown.filter_map { |step| step.employee_master&.name }.uniq.join(", ").presence || "-",
      approver_role: shown.first&.employee_master&.designation.presence || shown.first&.current_action_label,
      submitted_at: approval_request.created_at&.in_time_zone("Asia/Kolkata")
    )
  end

  def approval_status_tone(approval_request)
    case approval_request.status
    when "approved" then "green"
    when "returned" then "orange"
    when "rejected" then "red"
    else "amber"
    end
  end

end
