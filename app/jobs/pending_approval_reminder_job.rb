class PendingApprovalReminderJob < ApplicationJob
  queue_as :default

  def perform
    ApprovalRequest.includes(:approvable, approval_steps: :employee_master)
      .where(status: "pending")
      .find_each do |approval_request|
        next if approval_request.created_at > 24.hours.ago

        NotificationDispatcher.notify_pending_approval_reminder_steps(approval_request)
      end
  end
end
