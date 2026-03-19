class ProductVariety < ApplicationRecord
  belongs_to :product
  has_many :vendor_registration_product_varieties, dependent: :destroy
  has_many :vendor_registrations, through: :vendor_registration_product_varieties

  delegate :theme, to: :product

  validates :name, presence: true
end
