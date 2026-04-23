class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum :role, { user: 0, admin: 1 }, default: :user, validate: true

  has_many :notifications, dependent: :destroy
  has_many :vendor_registrations, dependent: :destroy

  before_validation :normalize_email

  validate :admin_role_requires_admin_employee_master
  validate :role_matches_employee_master, if: :employee_master

  def employee_master
    lookup_email = email.to_s.strip.downcase
    return if lookup_email.blank?

    EmployeeMaster.find_by("LOWER(TRIM(email_id)) = ?", lookup_email)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def admin_role_requires_admin_employee_master
    return unless role.to_s == "admin"
    return if employee_master&.user_type == "Admin"

    errors.add(:role, "can be Admin only when the email belongs to an Admin employee master record")
  end

  def role_matches_employee_master
    employee_role = employee_master.user_type.to_s.strip.downcase
    return if employee_role.blank? || role.to_s == employee_role

    errors.add(:role, "must match the employee master role (#{employee_role.titleize})")
  end
end
