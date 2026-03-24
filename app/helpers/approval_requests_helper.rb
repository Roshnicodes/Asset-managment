module ApprovalRequestsHelper
  def pending_approvals_count
    if current_user.email == "admin@example.com"
      return ApprovalRequest.where(status: "pending").count
    end
    return 0 unless current_employee_master.present?
    
    ApprovalRequest.joins(:approval_steps)
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

  def total_approvals_count
    pending_approvals_count + approved_approvals_count + rejected_approvals_count
  end
end
