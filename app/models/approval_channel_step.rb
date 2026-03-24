class ApprovalChannelStep < ApplicationRecord
  belongs_to :approval_channel
  belongs_to :from_user, class_name: "EmployeeMaster", optional: true
  belongs_to :to_responsible_user, class_name: "EmployeeMaster"

  validates :step_number, :current_action, presence: true
  validates :step_number, uniqueness: { scope: :approval_channel_id }
  validate :first_step_previous_action_should_be_blank
  validate :actions_must_be_different

  scope :ordered, -> { order(:step_number) }

  def flow_label
    from_name = from_user&.name.presence || "System"
    "#{from_name} -> #{to_responsible_user.name} (#{current_action})"
  end

  private

  def first_step_previous_action_should_be_blank
    return unless step_number.to_i == 1 && previous_action.present? && previous_action != "NA"

    errors.add(:previous_action, "must be blank or 'NA' for the first approval step")
  end

  def actions_must_be_different
    return if previous_action.blank? || current_action.blank?
    return if previous_action == "NA"
    return unless previous_action == current_action

    errors.add(:current_action, "must be different from Previous Action")
  end
end
