class ApprovalRequestBuilder
  def self.create_for!(record, form_name:)
    stakeholder_category_id = record.try(:stakeholder_category_id)
    theme_ids = record.try(:theme_ids).presence || []

    candidate_scope = ApprovalChannel
      .includes(:approval_channel_steps)
      .where(form_name: form_name)

    if stakeholder_category_id.present?
      candidate_scope = candidate_scope.where(stakeholder_category_id: [stakeholder_category_id, nil])
    end

    if theme_ids.any?
      candidate_scope = candidate_scope.where(theme_id: theme_ids + [nil])
    else
      theme_scoped_channels = candidate_scope.where(theme_id: nil)
      candidate_scope = theme_scoped_channels.exists? ? theme_scoped_channels : candidate_scope
    end

    candidate_channels = candidate_scope.to_a
    return nil if candidate_channels.empty?

    creator_employee = creator_employee_for(record)
    approval_channel = select_approval_channel(
      candidate_channels: candidate_channels,
      creator_employee: creator_employee,
      stakeholder_category_id: stakeholder_category_id,
      theme_ids: theme_ids
    )

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

  def self.creator_employee_for(record)
    user = record.try(:user)
    return unless user

    user.employee_master || EmployeeMaster.find_by("LOWER(email_id) = ?", user.email.to_s.downcase)
  end

  def self.select_approval_channel(candidate_channels:, creator_employee:, stakeholder_category_id:, theme_ids:)
    usable_channels = candidate_channels.select { |channel| channel.flow_steps.any? }
    return nil if usable_channels.empty?

    usable_channels.max_by do |channel|
      first_step = channel.flow_steps.first

      [
        exact_theme_score(channel, theme_ids),
        exact_stakeholder_score(channel, stakeholder_category_id),
        creator_match_score(first_step, creator_employee),
        channel.flow_steps.size,
        channel.id
      ]
    end
  end

  def self.creator_match_score(first_step, creator_employee)
    return 0 unless first_step && creator_employee

    from_user_id = first_step.try(:from_user_id) || first_step.try(:from_user)&.id
    to_user_id = first_step.try(:to_responsible_user_id) || first_step.try(:to_responsible_user)&.id

    from_match = from_user_id.to_i == creator_employee.id ? 2 : 0
    to_match = to_user_id.to_i == creator_employee.id ? 1 : 0
    from_match + to_match
  end

  def self.exact_stakeholder_score(channel, stakeholder_category_id)
    return 0 if stakeholder_category_id.blank?
    return 2 if channel.stakeholder_category_id == stakeholder_category_id
    return 1 if channel.stakeholder_category_id.nil?

    0
  end

  def self.exact_theme_score(channel, theme_ids)
    return 1 if channel.theme_id.nil?
    return 3 if theme_ids.include?(channel.theme_id)

    0
  end
end
