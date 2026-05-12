class ProductVariety < ApplicationRecord
  before_validation :normalize_product_type_code

  belongs_to :product
  belongs_to :stakeholder_category, optional: true
  has_many :vendor_registration_product_varieties, dependent: :destroy
  has_many :vendor_registrations, through: :vendor_registration_product_varieties

  delegate :theme, to: :product

  validates :name, presence: true
  validates :product_type_code, uniqueness: true, allow_blank: true

  private

  def normalize_product_type_code
    self.product_type_code = product_type_code.to_s.strip.presence
  end
end
