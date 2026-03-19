class Theme < ApplicationRecord
  has_many :products, dependent: :restrict_with_error
  has_many :vendor_registration_themes, dependent: :destroy
  has_many :vendor_registrations, through: :vendor_registration_themes

  validates :name, presence: true
end
