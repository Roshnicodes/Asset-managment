class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :notifications, dependent: :destroy
  has_many :vendor_registrations, dependent: :destroy

  def employee_master
    EmployeeMaster.where("LOWER(email_id) = ?", email.downcase).first
  end
end
