class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :notifications, dependent: :destroy
  has_many :vendor_registrations, dependent: :destroy

  def employee_master
    lookup_email = email.to_s.strip.downcase
    return if lookup_email.blank?

    EmployeeMaster.find_by("LOWER(TRIM(email_id)) = ?", lookup_email)
  end
end
