class Pmu < ApplicationRecord
  belongs_to :district
  belongs_to :block, optional: true
  has_many :fcos, dependent: :restrict_with_error

  def location_district
    block&.district || district
  end

  def state
    location_district&.state
  end
end
