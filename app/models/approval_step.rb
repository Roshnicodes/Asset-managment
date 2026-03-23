class ApprovalStep < ApplicationRecord
  belongs_to :approval_request
  belongs_to :employee_master
  belongs_to :from_user, class_name: "EmployeeMaster", optional: true

  STATUSES = %w[waiting pending approved rejected].freeze

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
end
