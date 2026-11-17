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
  validate :name_not_duplicated_in_theme, if: -> { new_record? || will_save_change_to_name? || will_save_change_to_theme_id? }
  validate :code_not_duplicated, if: -> { product_code.present? && (new_record? || will_save_change_to_product_code?) }

  def asset_code_segment
    product_code.to_s.strip.presence || name.to_s.strip
  end

  def asset_product_type_code_segment
    product_varieties.min_by(&:id)&.product_type_code.to_s.strip.presence
  end

  private

  def normalize_product_code
    self.product_code = product_code.to_s.strip.presence
    self.name = name.to_s.squish.presence if will_save_change_to_name? || new_record?
  end

  # The same product (ignoring case and extra spaces) is entered only once per theme.
  def name_not_duplicated_in_theme
    return if name.blank? || theme_id.blank?

    duplicate = Product.where(theme_id: theme_id)
      .where("LOWER(REGEXP_REPLACE(TRIM(name), '\\s+', ' ', 'g')) = ?", name.to_s.squish.downcase)
      .where.not(id: id)
    errors.add(:name, "\"#{name}\" already exists in this theme.") if duplicate.exists?
  end

  def code_not_duplicated
    duplicate = Product.where("LOWER(TRIM(product_code)) = ?", product_code.to_s.strip.downcase).where.not(id: id)
    errors.add(:product_code, "\"#{product_code}\" is already used by another product.") if duplicate.exists?
  end
end
