class NotificationDispatcher
  def self.notify_approval_step(approval_request, approval_step, previous_step: nil)
    user = User.find_by(email: approval_step.employee_master.email_id)
    return unless user

    reference_name = approval_request.reference_label
    message =
      if previous_step.present?
        "#{reference_name} moved from #{previous_step.current_action_label} to #{approval_step.current_action_label} after approval by #{previous_step.employee_master.name}."
      else
        "#{reference_name} has been submitted and is waiting for your action: #{approval_step.current_action_label}."
      end

    Notification.create!(
      user: user,
      notifiable: approval_request,
      title: "#{approval_request.form_name} - #{approval_step.current_action_label}",
      message: message
    )
  end

  def self.notify_request_completed(approval_request, status:, actor:, remark: nil)
    users = approval_request.approval_steps.includes(:employee_master).map do |step|
      User.find_by(email: step.employee_master.email_id)
    end.compact.uniq

    users.each do |user|
      Notification.create!(
        user: user,
        notifiable: approval_request,
        title: "#{approval_request.form_name} #{status}",
        message: "#{approval_request.reference_label} was #{status} by #{actor.name}.#{remark.present? ? " Remark: #{remark}" : ""}"
      )
    end
  end
end
