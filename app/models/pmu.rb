class Pmu < ApplicationRecord
  belongs_to :district
  has_many :fcos, dependent: :restrict_with_error
end
