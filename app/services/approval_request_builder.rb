class ApprovalRequestBuilder
  def self.create_for!(record, form_name:)
    approval_channel = ApprovalChannel.find_by(form_name: form_name, stakeholder_category_id: record.try(:stakeholder_category_id)) ||
      ApprovalChannel.find_by(form_name: form_name, stakeholder_category_id: nil)

    return nil unless approval_channel

    employees = [
      approval_channel.level_1_employee,
      approval_channel.level_2_employee,
      approval_channel.level_3_employee
    ].compact

    return nil if employees.empty?

    approval_request = ApprovalRequest.create!(
      approval_channel: approval_channel,
      approvable: record,
      form_name: form_name,
      status: "pending",
      current_level: 1
    )

    employees.each_with_index do |employee, index|
      approval_request.approval_steps.create!(
        employee_master: employee,
        level: index + 1,
        status: index.zero? ? "pending" : "waiting"
      )
    end

    NotificationDispatcher.notify_approval_step(approval_request, approval_request.approval_steps.first)

    approval_request
  end
end
