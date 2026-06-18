class Block < ApplicationRecord
  belongs_to :district
  has_many :pmus, dependent: :restrict_with_error
  has_many :employee_masters, dependent: :restrict_with_error
  has_many :office_categories, dependent: :restrict_with_error
  has_many :vendor_registrations, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, uniqueness: { scope: :district_id }, allow_blank: true
end
