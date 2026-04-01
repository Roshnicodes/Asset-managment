class ApprovalStep < ApplicationRecord
  belongs_to :approval_request
  belongs_to :employee_master
  belongs_to :from_user, class_name: "EmployeeMaster", optional: true

  STATUSES = %w[waiting pending approved returned rejected].freeze

  validates :status, inclusion: { in: STATUSES }

  def action_label
    "#{employee_master.name} (#{employee_master.designation.presence || 'Employee'})"
  end

  def current_action_label
    current_action.presence || "Approval"
  end

  def previous_action_label
    previous_action.presence || "-"
  end

  def effective_status
    # UI-level override: Step 1 (Proposal Create) should always show as approved
    is_initial_step = (level == 1 && (previous_action.to_s.strip == "NA" || previous_action.to_s.strip.blank?) && current_action.to_s.strip == "Proposal Create")
    is_initial_step ? "approved" : status
  end

  def effective_status_label
    return "Returned" if effective_status == "returned"
    return "Rejected" if effective_status == "rejected"

    effective_status.capitalize
  end

  def proposal_create_step?
    level == 1 && current_action.to_s.strip == "Proposal Create"
  end

  def show_status_in_trail?
    !proposal_create_step?
  end
end
