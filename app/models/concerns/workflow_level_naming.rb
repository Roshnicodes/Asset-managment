module WorkflowLevelNaming
  module_function

  def committee_member_label(level)
    "Committee Member #{level.to_i}"
  end

  def approval_status_label_for(step, approval_request: nil)
    status = step.respond_to?(:effective_status) ? step.effective_status.to_s : step.status.to_s

    return "Returned" if status == "returned"
    return "Rejected" if status == "rejected"
    return status.capitalize unless status == "approved"

    approval_request ||= step.try(:approval_request)
    return "Approved" unless vendor_registration_display_flow?(approval_request)
    return "Approved" if initial_auto_approved_step?(step, approval_request: approval_request)
    return "Approved" if approval_request&.committee_parallel_flow?

    actionable_steps = actionable_approval_steps(approval_request)
    return "Approved" if actionable_steps.size <= 1

    step_index = actionable_steps.index { |candidate| candidate.level.to_i == step.level.to_i }
    return "Approved" if step_index.nil?
    return "Approved" if step_index == actionable_steps.size - 1
    return "Verify" if step_index == actionable_steps.size - 2

    "Recommended"
  end

  def humanize_action_label(label)
    text = label.to_s
    return "-" if text.blank?

    text
      .gsub(/\bL(\d+)\s+Approval\b/i) { "#{committee_member_label(Regexp.last_match(1))} Approval" }
      .gsub(/\bL(\d+)\s+Approved\b/i) { "#{committee_member_label(Regexp.last_match(1))} Approved" }
  end

  def humanize_level_label(level)
    committee_member_label(level)
  end

  def actionable_approval_steps(approval_request)
    return [] unless approval_request

    approval_request
      .approval_steps
      .sort_by { |step| step.level.to_i }
      .reject { |step| initial_auto_approved_step?(step, approval_request: approval_request) }
  end

  def initial_auto_approved_step?(step, approval_request: nil)
    return true if proposal_create_step?(step)
    return false unless step.level.to_i == 1

    creator_email = approval_request&.approvable&.try(:user)&.try(:email).to_s.strip.downcase
    approver_email = step.try(:employee_master)&.email_id.to_s.strip.downcase

    creator_email.present? && approver_email == creator_email
  end

  def proposal_create_step?(step)
    return step.proposal_create_step? if step.respond_to?(:proposal_create_step?)

    step.level.to_i == 1 && step.current_action.to_s.strip == "Proposal Create"
  end

  def vendor_registration_display_flow?(approval_request)
    return false unless approval_request

    approval_request.form_name.to_s == "Vendor Registration" ||
      approval_request.approvable.is_a?(VendorRegistration)
  end
end
