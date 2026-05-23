class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  attribute :role, :integer
  enum :role, { user: 0, admin: 1 }, default: :user, validate: true

  has_many :notifications, dependent: :destroy
  has_many :vendor_registrations, dependent: :destroy

  attr_writer :login

  before_validation :normalize_email
  before_validation :assign_default_role

  validate :admin_role_requires_admin_employee_master
  validate :role_matches_employee_master, if: :employee_master

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    employee_code = conditions.delete(:email).to_s.strip
    return nil if employee_code.blank? || employee_code.include?("@")

    employee = EmployeeMaster.find_by("LOWER(TRIM(employee_code)) = ?", employee_code.downcase)
    return nil if employee&.email_id.blank?

    find_by("LOWER(TRIM(email)) = ?", employee.email_id.to_s.strip.downcase)
  end

  def login
    @login || employee_master&.employee_code || email
  end

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

  def admin_role_requires_admin_employee_master
    return unless role.to_s == "admin"
    return if employee_master&.user_type.to_s.strip.casecmp("Admin").zero?

    errors.add(:role, "can be Admin only when the email belongs to an Admin employee master record")
  end

  def role_matches_employee_master
    employee_role = employee_master.user_type.to_s.strip.downcase
    return if employee_role.blank? || role.to_s == employee_role

    errors.add(:role, "must match the employee master role (#{employee_role.titleize})")
  end
end
