module ApprovalRequestsHelper
  def pending_approvals_count(form_name = nil)
    scope = ApprovalRequest.where(status: "pending")
    scope = scope.where(form_name: form_name) if form_name.present?

    if current_user.email == "admin@example.com"
      return scope.count
    end
    return 0 unless current_employee_master.present?
    
    scope.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_employee_master.id, status: "pending" })
      .distinct
      .count
  end

  def approved_approvals_count
    if current_user.email == "admin@example.com"
      return ApprovalRequest.where(status: "approved").count
    end
    return 0 unless current_employee_master.present?
    
    ApprovalRequest.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_employee_master.id, status: "approved" })
      .where(status: "approved")
      .distinct
      .count
  end

  def rejected_approvals_count
    if current_user.email == "admin@example.com"
      return ApprovalRequest.where(status: "rejected").count
    end
    return 0 unless current_employee_master.present?
    
    ApprovalRequest.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_employee_master.id, status: "rejected" })
      .where(status: "rejected")
      .distinct
      .count
  end

  def returned_approvals_count
    if current_user.email == "admin@example.com"
      return ApprovalRequest.where(status: "returned").count
    end
    return 0 unless current_employee_master.present?

    ApprovalRequest.joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_employee_master.id, status: "returned" })
      .where(status: "returned")
      .distinct
      .count
  end

  def total_approvals_count
    pending_approvals_count + approved_approvals_count + returned_approvals_count + rejected_approvals_count
  end
end
