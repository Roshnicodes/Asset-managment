class RegistrationType < ApplicationRecord
  belongs_to :stakeholder_category, optional: true
  has_many :vendor_registrations, dependent: :restrict_with_error

  validates :name, presence: true
end
