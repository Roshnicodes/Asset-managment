class ApprovalChannelStep < ApplicationRecord
  belongs_to :approval_channel
  belongs_to :from_user, class_name: "EmployeeMaster", optional: true
  belongs_to :to_responsible_user, class_name: "EmployeeMaster"

  validates :step_number, :current_action, presence: true
  validates :step_number, uniqueness: { scope: :approval_channel_id }
  validate :first_step_previous_action_should_be_blank
  validate :users_must_be_different

  scope :ordered, -> { order(:step_number) }

  def flow_label
    from_name = from_user&.name.presence || "System"
    "#{from_name} -> #{to_responsible_user.name} (#{current_action})"
  end

  private

  def first_step_previous_action_should_be_blank
    return unless step_number.to_i == 1 && previous_action.present?

    errors.add(:previous_action, "must be blank for the first approval step")
  end

  def users_must_be_different
    return if from_user_id.blank? || to_responsible_user_id.blank?
    return unless from_user_id == to_responsible_user_id

    errors.add(:to_responsible_user_id, "must be different from From User")
  end
end
