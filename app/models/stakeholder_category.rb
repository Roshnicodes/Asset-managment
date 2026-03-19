class StakeholderCategory < ApplicationRecord
  belongs_to :office_category, optional: true

  validates :name, presence: true
end
