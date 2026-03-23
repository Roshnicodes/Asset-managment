class ApprovalStep < ApplicationRecord
  belongs_to :approval_request
  belongs_to :employee_master

  STATUSES = %w[waiting pending approved rejected].freeze

  validates :status, inclusion: { in: STATUSES }

  def action_label
    "#{employee_master.name} (#{employee_master.designation.presence || 'Employee'})"
  end
end
