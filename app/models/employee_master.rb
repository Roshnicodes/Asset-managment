class EmployeeMaster < ApplicationRecord
  belongs_to :stakeholder_category

  validates :employee_code, :name, presence: true
  validates :employee_code, uniqueness: true
end
