class ApprovalRequestBuilder
  def self.create_for!(record, form_name:)
    approval_channel = ApprovalChannel.find_by(form_name: form_name, stakeholder_category_id: record.try(:stakeholder_category_id)) ||
      ApprovalChannel.find_by(form_name: form_name, stakeholder_category_id: nil)

    return nil unless approval_channel

    channel_steps = approval_channel.flow_steps
    return nil if channel_steps.empty?

    approval_request = ApprovalRequest.create!(
      approval_channel: approval_channel,
      approvable: record,
      form_name: form_name,
      status: "pending",
      current_level: 1
    )

    channel_steps.each_with_index do |channel_step, index|
      approval_request.approval_steps.create!(
        employee_master: channel_step.to_responsible_user,
        from_user: channel_step.try(:from_user),
        previous_action: channel_step.previous_action,
        current_action: channel_step.current_action,
        level: channel_step.step_number || index + 1,
        status: index.zero? ? "pending" : "waiting"
      )
    end

    NotificationDispatcher.notify_approval_step(approval_request, approval_request.approval_steps.first)

    approval_request
  end
end
