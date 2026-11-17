class ProductVariety < ApplicationRecord
  before_validation :normalize_product_type_code

  belongs_to :product
  belongs_to :stakeholder_category, optional: true
  has_many :vendor_registration_product_varieties, dependent: :destroy
  has_many :vendor_registrations, through: :vendor_registration_product_varieties

  delegate :theme, to: :product

  validates :name, presence: true
  validates :product_type_code, uniqueness: true, allow_blank: true
  validate :name_not_duplicated_in_product, if: -> { new_record? || will_save_change_to_name? || will_save_change_to_product_id? }
  validate :code_not_duplicated, if: -> { product_type_code.present? && (new_record? || will_save_change_to_product_type_code?) }

  private

  def normalize_product_type_code
    self.product_type_code = product_type_code.to_s.strip.presence
    self.name = name.to_s.squish.presence if will_save_change_to_name? || new_record?
  end

  # The same product type (ignoring case and extra spaces) is entered only once per product.
  def name_not_duplicated_in_product
    return if name.blank? || product_id.blank?

    duplicate = ProductVariety.where(product_id: product_id)
      .where("LOWER(REGEXP_REPLACE(TRIM(name), '\\s+', ' ', 'g')) = ?", name.to_s.squish.downcase)
      .where.not(id: id)
    errors.add(:name, "\"#{name}\" already exists for this product.") if duplicate.exists?
  end

  def code_not_duplicated
    duplicate = ProductVariety.where("LOWER(TRIM(product_type_code)) = ?", product_type_code.to_s.strip.downcase).where.not(id: id)
    errors.add(:product_type_code, "\"#{product_type_code}\" is already used by another product type.") if duplicate.exists?
  end
end
