class Fco < ApplicationRecord
  belongs_to :pmu
  has_many :tos, dependent: :restrict_with_error
end
