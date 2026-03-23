class ApprovalChannel < ApplicationRecord
  belongs_to :stakeholder_category, optional: true
  belongs_to :level_1_employee, class_name: "EmployeeMaster", optional: true
  belongs_to :level_2_employee, class_name: "EmployeeMaster", optional: true
  belongs_to :level_3_employee, class_name: "EmployeeMaster", optional: true

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
  validate :at_least_one_approver_selected
  validate :approver_levels_must_be_unique
  validate :configured_approvers_must_have_login_email

  after_commit :provision_approver_logins, on: %i[create update]

  def configured_approvers
    [level_1_employee, level_2_employee, level_3_employee].compact
  end

  def configured_levels_label
    configured_approvers.each_with_index.map { |employee, index| "L#{index + 1}: #{employee.name}" }.join(", ")
  end

  private

  def at_least_one_approver_selected
    return if configured_approvers.any?

    errors.add(:base, "Select at least one approval employee.")
  end

  def approver_levels_must_be_unique
    employee_ids = [
      level_1_employee_id,
      level_2_employee_id,
      level_3_employee_id
    ].compact

    return if employee_ids.uniq.size == employee_ids.size

    errors.add(:base, "Same employee cannot be selected in multiple approval levels.")
  end

  def configured_approvers_must_have_login_email
    missing_email_approvers = configured_approvers.select { |employee| employee.email_id.blank? }
    return if missing_email_approvers.empty?

    errors.add(:base, "#{missing_email_approvers.map(&:name).join(', ')} must have email ID for approval login.")
  end

  def provision_approver_logins
    configured_approvers.each do |employee|
      EmployeeLoginProvisioner.provision_for!(employee)
    end
  end
end
