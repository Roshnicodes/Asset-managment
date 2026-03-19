class Product < ApplicationRecord
  belongs_to :theme
  has_many :assets, dependent: :restrict_with_error
  has_many :product_varieties, dependent: :restrict_with_error
  has_many :vendor_registration_products, dependent: :destroy
  has_many :vendor_registrations, through: :vendor_registration_products

  validates :name, presence: true
end
