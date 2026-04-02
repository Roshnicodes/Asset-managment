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
end
