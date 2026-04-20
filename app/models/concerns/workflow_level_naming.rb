module WorkflowLevelNaming
  module_function

  def committee_member_label(level)
    "Committee Member #{level.to_i}"
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
end
