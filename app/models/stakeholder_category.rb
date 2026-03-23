class StakeholderCategory < ApplicationRecord
  belongs_to :office_category, optional: true
  has_many :employee_masters, dependent: :restrict_with_error
  has_one_attached :logo_file

  validates :name, presence: true
end
