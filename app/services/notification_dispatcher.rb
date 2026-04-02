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

  def self.notify_pending_approval_steps(approval_request, previous_step: nil)
    approval_request.approval_steps.where(status: "pending").order(:level).each do |approval_step|
      notify_approval_step(approval_request, approval_step, previous_step: previous_step)
    end
  end

  def self.notify_request_completed(approval_request, status:, actor:, remark: nil)
    users = approval_request.approval_steps.includes(:employee_master).map do |step|
      User.find_by(email: step.employee_master.email_id)
    end.compact.uniq
    users << approval_request.approvable.user if approval_request.approvable.respond_to?(:user)

    users.compact.uniq.each do |user|
      Notification.create!(
        user: user,
        notifiable: approval_request,
        title: "#{approval_request.form_name} #{status}",
        message: "#{approval_request.reference_label} was #{status} by #{actor.name}.#{remark.present? ? " Remark: #{remark}" : ""}"
      )
    end
  end

  def self.notify_request_returned(approval_request, actor:, remark:)
    users = [approval_request.approvable.user].compact
    users += approval_request.approval_steps.includes(:employee_master).map do |step|
      User.find_by(email: step.employee_master.email_id)
    end.compact

    users.uniq.each do |user|
      Notification.create!(
        user: user,
        notifiable: approval_request,
        title: "#{approval_request.form_name} returned",
        message: "#{approval_request.reference_label} was returned by #{actor.name}. Remark: #{remark}"
      )
    end
  end

  def self.notify_request_returned_to_step(approval_request, actor:, remark:, target_step:)
    user = User.find_by(email: target_step.employee_master.email_id)
    return unless user

    Notification.create!(
      user: user,
      notifiable: approval_request,
      title: "#{approval_request.form_name} returned to your level",
      message: "#{approval_request.reference_label} was returned by #{actor.name} to your level for re-approval. Remark: #{remark}"
    )
  end

  def self.notify_quotation_committee_step(quotation_proposal, committee_step, previous_step: nil)
    return unless committee_step

    user = User.find_by(email: committee_step.employee_master.email_id)
    return unless user

    message =
      if previous_step.present?
        "#{quotation_proposal.subject} is now pending for your L#{committee_step.level} committee action after L#{previous_step.level} approval."
      else
        "#{quotation_proposal.subject} is pending for your committee approval."
      end

    Notification.create!(
      user: user,
      notifiable: quotation_proposal,
      title: "Quotation Proposal Committee Approval",
      message: message
    )
  end

  def self.notify_all_quotation_committee_steps(quotation_proposal)
    quotation_proposal.committee_steps.where(status: "pending").find_each do |committee_step|
      notify_quotation_committee_step(quotation_proposal, committee_step)
    end
  end

  def self.notify_quotation_committee_completed(quotation_proposal, actor:, remark: nil)
    users = quotation_proposal.committee_steps.includes(:employee_master).map do |step|
      User.find_by(email: step.employee_master.email_id)
    end.compact
    users << quotation_proposal.user if quotation_proposal.user.present?

    users.compact.uniq.each do |user|
      Notification.create!(
        user: user,
        notifiable: quotation_proposal,
        title: "Quotation Proposal Approved",
        message: "#{quotation_proposal.subject} has been approved by the committee. Approved by #{actor.name}.#{remark.present? ? " Remark: #{remark}" : ""}"
      )
    end
  end

  def self.notify_quotation_committee_returned(quotation_proposal, actor:, remark:)
    users = [quotation_proposal.user].compact
    users += quotation_proposal.committee_steps.includes(:employee_master).map do |step|
      User.find_by(email: step.employee_master.email_id)
    end.compact

    users.uniq.each do |user|
      Notification.create!(
        user: user,
        notifiable: quotation_proposal,
        title: "Quotation Proposal Returned",
        message: "#{quotation_proposal.subject} has been returned by #{actor.name}. Remark: #{remark}"
      )
    end
  end

  def self.notify_quotation_vendor_response_received(quotation_proposal, proposal_vendor)
    users = quotation_proposal.committee_steps.includes(:employee_master).map do |step|
      User.find_by(email: step.employee_master.email_id)
    end.compact
    users << quotation_proposal.user if quotation_proposal.user.present?

    users.compact.uniq.each do |user|
      Notification.create!(
        user: user,
        notifiable: quotation_proposal,
        title: "Vendor Response Received",
        message: "#{proposal_vendor.vendor_registration.display_name} has submitted the quotation response for #{quotation_proposal.subject}. You can now review and compare vendor quotations."
      )
    end
  end
end
