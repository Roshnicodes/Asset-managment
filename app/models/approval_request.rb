class ApprovalRequest < ApplicationRecord
  belongs_to :approval_channel
  belongs_to :approvable, polymorphic: true
  has_many :approval_steps, -> { order(:level) }, dependent: :destroy

  STATUSES = %w[pending approved rejected].freeze

  validates :status, inclusion: { in: STATUSES }

  def current_step
    approval_steps.find_by(status: "pending")
  end

  def reference_label
    approvable.try(:display_name) || "#{approvable_type} ##{approvable_id}"
  end

  def current_approver_label
    return "-" unless current_step

    "#{current_step.action_label} - #{current_step.current_action_label}"
  end

  def status_label
    status == "rejected" ? "Returned" : status.capitalize
  end

  def latest_remark
    approval_steps.where.not(remark: [nil, ""]).order(actioned_at: :desc, updated_at: :desc).pick(:remark)
  end

  def approval_history_label
    approval_steps.map do |step|
      detail = "Step #{step.level} #{step.action_label} [#{step.previous_action_label} -> #{step.current_action_label}]: #{step.effective_status_label}"
      detail = "#{detail} on #{step.actioned_at.strftime('%d-%m-%Y %H:%M')}" if step.actioned_at.present?
      step.remark.present? ? "#{detail} (#{step.remark})" : detail
    end.join(" | ")
  end

  def approve!(employee:, remark: nil)
    step = approval_steps.find_by!(employee_master: employee, status: "pending")
    step.update!(status: "approved", remark: remark, actioned_at: Time.current)

    next_step = approval_steps.where("level > ?", step.level).find_by(status: "waiting")
    if next_step
      next_step.update!(status: "pending")
      update!(current_level: next_step.level, status: "pending")
      NotificationDispatcher.notify_approval_step(self, next_step, previous_step: step)
    else
      update!(current_level: nil, status: "approved")
      NotificationDispatcher.notify_request_completed(self, status: "approved", actor: employee, remark: remark)
    end
  end

  def reject!(employee:, remark:)
    step = approval_steps.find_by!(employee_master: employee, status: "pending")
    step.update!(status: "rejected", remark: remark, actioned_at: Time.current)
    update!(current_level: nil, status: "rejected")
    NotificationDispatcher.notify_request_completed(self, status: "rejected", actor: employee, remark: remark)
  end
end
