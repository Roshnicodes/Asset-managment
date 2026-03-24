class ApprovalRequestBuilder
  def self.create_for!(record, form_name:)
    query = ApprovalChannel.where(form_name: form_name)
    if form_name == "Vendor Registration" && record.respond_to?(:theme_ids) && record.theme_ids.any?
      query = query.where(theme_id: record.theme_ids).or(query.where(theme_id: nil))
    else
      query = query.where(theme_id: nil)
    end

    # Prioritize specifically for this stakeholder category if it exists
    stakeholder_category_id = record.try(:stakeholder_category_id)
    query = query.where(stakeholder_category_id: stakeholder_category_id) if stakeholder_category_id.present?

    # Find the creator of the record
    creator_employee = record.try(:user)&.employee_master

    # Filter by creator: find channel where at least one step has from_user = creator_employee
    # Or more precisely, where the first step should start from this creator.
    approval_channel = if creator_employee
      query.joins(:approval_channel_steps)
           .where(approval_channel_steps: { step_number: 1, from_user_id: creator_employee.id })
           .first
    end

    # Fallback to general lookup if no specific creator-based channel found
    approval_channel ||= query.find_by(stakeholder_category_id: stakeholder_category_id)
    approval_channel ||= query.find_by(stakeholder_category_id: nil) if stakeholder_category_id.nil?

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

    creator_email = record.try(:user).try(:email).to_s.downcase

    channel_steps.each_with_index do |channel_step, index|
      prev_act = channel_step.previous_action.to_s.strip
      curr_act = channel_step.current_action.to_s.strip
      approver_email = channel_step.to_responsible_user.email_id.to_s.downcase
      
      # Step 1 is auto-approved if it's Proposal Create OR assigned to creator
      is_initial_step = index.zero? && (
        (prev_act == "NA" || prev_act.blank?) && curr_act == "Proposal Create" ||
        (approver_email == creator_email && !creator_email.blank?)
      )
      
      # Determine if second step should be pending
      first_step_will_be_approved = (channel_steps.first.previous_action.to_s.strip.blank? || channel_steps.first.previous_action.to_s.strip == "NA") && 
                                     channel_steps.first.current_action.to_s.strip == "Proposal Create"

      status = if is_initial_step
                 "approved"
               elsif index.zero?
                 "pending"
               elsif index == 1
                 # Step 2 becomes pending if Step 1 was auto-approved
                 first_step = channel_steps.first
                 fs_prev = first_step.previous_action.to_s.strip
                 fs_curr = first_step.current_action.to_s.strip
                 fs_approver = first_step.to_responsible_user.email_id.to_s.downcase
                 
                 fs_was_auto_approved = ((fs_prev == "NA" || fs_prev.blank?) && fs_curr == "Proposal Create") ||
                                       (fs_approver == creator_email && !creator_email.blank?)
                 
                 fs_was_auto_approved ? "pending" : "waiting"
               else
                 "waiting"
               end

      approval_request.approval_steps.create!(
        employee_master: channel_step.to_responsible_user,
        from_user: channel_step.try(:from_user),
        previous_action: channel_step.previous_action,
        current_action: channel_step.current_action,
        level: channel_step.step_number || index + 1,
        status: status,
        actioned_at: (status == "approved" ? Time.current : nil)
      )
    end

    notification_step = approval_request.approval_steps.find_by(status: "pending")
    if notification_step
      approval_request.update!(current_level: notification_step.level)
      NotificationDispatcher.notify_approval_step(approval_request, notification_step)
    end

    approval_request
  end
end
