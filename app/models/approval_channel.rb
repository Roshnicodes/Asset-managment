class ApprovalChannel < ApplicationRecord
  LegacyFlowStep = Struct.new(:step_number, :previous_action, :current_action, :to_responsible_user, :from_user, keyword_init: true)

  belongs_to :stakeholder_category, optional: true
  belongs_to :level_1_employee, class_name: "EmployeeMaster", optional: true
  belongs_to :level_2_employee, class_name: "EmployeeMaster", optional: true
  belongs_to :level_3_employee, class_name: "EmployeeMaster", optional: true
  has_many :approval_channel_steps, -> { order(:step_number) }, dependent: :destroy, inverse_of: :approval_channel

  accepts_nested_attributes_for :approval_channel_steps, allow_destroy: true, reject_if: :all_blank

  FORM_NAMES = [
    "Vendor Registration",
    "Product Entry",
    "Product Variety Entry",
    "Vendor Bank Master",
    "Quotation Request",
    "Vendor Quotation Response"
  ].freeze

  APPROVAL_TYPES = ["Sequential", "Parallel"].freeze

  validates :form_name, :approval_type, presence: true
  validate :at_least_one_approval_step_selected
  validate :approval_step_users_must_have_login_email
  validate :approval_steps_must_be_unique_and_ordered

  after_commit :provision_approver_logins, on: %i[create update]

  def configured_approvers
    if active_approval_channel_steps.any?
      active_approval_channel_steps.map(&:to_responsible_user).compact
    else
      [level_1_employee, level_2_employee, level_3_employee].compact
    end
  end

  def flow_steps
    active_approval_channel_steps.any? ? active_approval_channel_steps : legacy_flow_steps
  end

  def configured_levels_label
    flow_steps.map do |step|
      "Step #{step.step_number}: #{step.previous_action.presence || 'Blank'} -> #{step.current_action}"
    end.join(", ")
  end

  private

  def at_least_one_approval_step_selected
    return if flow_steps.any?

    errors.add(:base, "Add at least one approval step.")
  end

  def approval_step_users_must_have_login_email
    missing_email_approvers = configured_approvers.select { |employee| employee.email_id.blank? }
    return if missing_email_approvers.empty?

    errors.add(:base, "#{missing_email_approvers.map(&:name).join(', ')} must have email ID for approval login.")
  end

  def approval_steps_must_be_unique_and_ordered
    kept_steps = active_approval_channel_steps
    step_numbers = kept_steps.map { |step| step.step_number.to_i }
    return if step_numbers.empty?

    if step_numbers.uniq.size != step_numbers.size
      errors.add(:base, "Step number must be unique for each approval row.")
    end

    expected = (1..kept_steps.size).to_a
    return if step_numbers.sort == expected

    errors.add(:base, "Approval steps must be in continuous order like 1, 2, 3...")
  end

  def provision_approver_logins
    configured_approvers.each do |employee|
      EmployeeLoginProvisioner.provision_for!(employee)
    end
  end

  def active_approval_channel_steps
    approval_channel_steps.reject(&:marked_for_destruction?)
  end

  def legacy_flow_steps
    configured_approvers.each_with_index.map do |employee, index|
      LegacyFlowStep.new(
        step_number: index + 1,
        previous_action: index.zero? ? nil : "L#{index} Approved",
        current_action: index.zero? ? "Proposal Create" : "L#{index + 1} Approval",
        to_responsible_user: employee,
        from_user: nil
      )
    end
  end
end
