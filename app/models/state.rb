class State < ApplicationRecord
  has_many :districts, dependent: :restrict_with_error
  has_many :vendor_registrations, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, uniqueness: true, allow_blank: true
end
