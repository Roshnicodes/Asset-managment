class EmployeeMaster < ApplicationRecord
  require Rails.root.join("app/services/employee_login_provisioner")

  attr_accessor :password, :password_confirmation

  belongs_to :stakeholder_category
  belongs_to :state, optional: true
  belongs_to :district, optional: true
  belongs_to :block, optional: true

  USER_TYPES = ["User", "Admin"].freeze

  validates :name, :email_id, :user_type, presence: true
  validates :employee_code, uniqueness: true, allow_blank: true
  validates :email_id, uniqueness: true
  validates :user_type, inclusion: { in: USER_TYPES }
  validate :passwords_must_match
  validate :district_belongs_to_state
  validate :block_belongs_to_district

  after_commit :provision_login_access, on: %i[create update]

  def login_ready?
    User.exists?(email: email_id.to_s.strip.downcase)
  end

  private

  def provision_login_access
    ::EmployeeLoginProvisioner.provision_for!(self, password: password, password_confirmation: password_confirmation)
  end

  def passwords_must_match
    return if password.blank? && password_confirmation.blank?
    return if password == password_confirmation

    errors.add(:password_confirmation, "does not match password")
  end

  def district_belongs_to_state
    return if district.blank? || state.blank? || district.state_id == state_id

    errors.add(:district_id, "must belong to the selected state")
  end

  def block_belongs_to_district
    return if block.blank? || district.blank? || block.district_id == district_id

    errors.add(:block_id, "must belong to the selected district")
  end
end
