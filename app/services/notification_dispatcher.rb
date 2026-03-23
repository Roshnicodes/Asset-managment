class NotificationDispatcher
  def self.notify_approval_step(approval_request, approval_step, previous_step: nil)
    user = User.find_by(email: approval_step.employee_master.email_id)
    return unless user

    reference_name = approval_request.reference_label
    message =
      if previous_step.present?
        "#{reference_name} was approved by #{previous_step.employee_master.name} and is now waiting for your L#{approval_step.level} approval."
      else
        "#{reference_name} has been submitted and is waiting for your L#{approval_step.level} approval."
      end

    Notification.create!(
      user: user,
      notifiable: approval_request,
      title: "#{approval_request.form_name} approval pending",
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
