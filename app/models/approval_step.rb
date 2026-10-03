class ApprovalStep < ApplicationRecord
  belongs_to :approval_request
  belongs_to :employee_master
  belongs_to :from_user, class_name: "EmployeeMaster", optional: true

  STATUSES = %w[waiting pending approved returned rejected].freeze
  # A step is "reached" once the request has arrived at that approver: it is
  # pending on them now, or they already acted on it. Steps still "waiting"
  # belong to approvers the request has not reached yet, so those approvers
  # must not see the request in their lists.
  REACHED_STATUSES = %w[pending approved returned rejected].freeze

  scope :reached, -> { where(status: REACHED_STATUSES) }

  validates :status, inclusion: { in: STATUSES }

  def reached?
    status.in?(REACHED_STATUSES)
  end

  def action_label
    "#{employee_master.name} (#{employee_master.designation.presence || 'Employee'})"
  end

  def current_action_label
    WorkflowLevelNaming.humanize_action_label(current_action.presence || "Approval")
  end

  def previous_action_label
    WorkflowLevelNaming.humanize_action_label(previous_action.presence || "-")
  end

  def effective_status
    # UI-level override: Step 1 (Proposal Create) should always show as approved
    is_initial_step = (level == 1 && (previous_action.to_s.strip == "NA" || previous_action.to_s.strip.blank?) && current_action.to_s.strip == "Proposal Create")
    is_initial_step ? "approved" : status
  end

  def effective_status_label
    WorkflowLevelNaming.approval_status_label_for(self, approval_request: approval_request)
  end

  def proposal_create_step?
    level == 1 && current_action.to_s.strip == "Proposal Create"
  end

  def show_status_in_trail?
    !proposal_create_step?
  end
end
