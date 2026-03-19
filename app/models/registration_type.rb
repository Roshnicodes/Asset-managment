class RegistrationType < ApplicationRecord
  has_many :vendor_registrations, dependent: :restrict_with_error

  validates :name, presence: true
end
