class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  attribute :role, :integer
  enum :role, { user: 0, admin: 1 }, default: :user, validate: true

  has_many :notifications, dependent: :destroy
  has_many :vendor_registrations, dependent: :destroy

  before_validation :normalize_email
  before_validation :assign_default_role

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

  def assign_default_role
    self.role = "user" if role.blank?
  end

  def role_matches_employee_master
    employee_role = employee_master.user_type.to_s.strip.downcase
    return if employee_role.blank? || role.to_s == employee_role

    errors.add(:role, "must match the employee master role (#{employee_role.titleize})")
  end
end
