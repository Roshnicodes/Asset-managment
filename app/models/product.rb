class Product < ApplicationRecord
  before_validation :normalize_product_code

  belongs_to :theme
  belongs_to :stakeholder_category, optional: true
  has_many :assets, dependent: :restrict_with_error
  has_many :product_varieties, dependent: :restrict_with_error
  has_many :vendor_registration_products, dependent: :restrict_with_error
  has_many :vendor_registrations, through: :vendor_registration_products

  validates :name, presence: true
  validates :product_code, uniqueness: true, allow_blank: true

  def asset_code_segment
    product_code.to_s.strip.presence || name.to_s.strip
  end

  def asset_product_type_code_segment
    product_varieties.min_by(&:id)&.product_type_code.to_s.strip.presence
  end

  private

  def normalize_product_code
    self.product_code = product_code.to_s.strip.presence
  end
end
