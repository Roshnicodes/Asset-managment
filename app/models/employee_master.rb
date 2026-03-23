class EmployeeMaster < ApplicationRecord
  belongs_to :stakeholder_category

  validates :employee_code, :name, :email_id, presence: true
  validates :employee_code, uniqueness: true
  validates :email_id, uniqueness: true

  after_commit :provision_login_access, on: %i[create update]

  def login_ready?
    User.exists?(email: email_id.to_s.strip.downcase)
  end

  private

  def provision_login_access
    EmployeeLoginProvisioner.provision_for!(self)
  end
end
