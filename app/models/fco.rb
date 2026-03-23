class Fco < ApplicationRecord
  belongs_to :pmu
  has_many :tos, dependent: :restrict_with_error

  delegate :block, to: :pmu, allow_nil: true
  delegate :location_district, :state, to: :pmu

  def district
    location_district
  end
end
