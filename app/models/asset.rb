class Asset < ApplicationRecord
  STRUCTURED_ASSET_CODE_COLUMNS = %w[
    stakeholder_category_id
    primary_office_category_id
    secondary_office_category_id
    asset_code_date
    insured
    insurance_date
    insurance_company_name
    insurance_policy_number
    insurance_expiry_date
  ].freeze

  belongs_to :product
  belongs_to :stakeholder_category, optional: true
  belongs_to :primary_office_category, class_name: "OfficeCategory", optional: true
  belongs_to :secondary_office_category, class_name: "OfficeCategory", optional: true
  belongs_to :quotation_proposal_vendor_invoice_request, optional: true
  belongs_to :quotation_proposal_vendor_item, optional: true
  has_many :allocations, dependent: :destroy

  before_validation :normalize_asset_code_inputs
  before_validation :normalize_insurance_inputs
  before_validation :assign_default_serial_number, on: :create
  before_validation :assign_default_item_code_from_product
  before_validation :assign_asset_code
  before_validation :clear_insurance_details_unless_insured

  validates :serial_number, uniqueness: true, allow_blank: true
  validates :name, :unique_product_code, :stakeholder_category, :primary_office_category, :secondary_office_category, :asset_code_date,
            presence: true,
            if: :structured_asset_code_required?
  validates :insurance_company_name, :insurance_policy_number, :insurance_date, :insurance_expiry_date, presence: true, if: :insured?
  validate :office_categories_belong_to_selected_stakeholder, if: :structured_asset_code_required?
  validate :office_locations_must_differ, if: :structured_asset_code_required?
  validate :insurance_expiry_date_must_follow_insurance_date, if: :insured?

  scope :serial_number_ascending, lambda {
    order(
      Arel.sql(
        "CASE WHEN serial_number ~ '^[0-9]+$' THEN 0 ELSE 1 END ASC, " \
        "CASE WHEN serial_number ~ '^[0-9]+$' THEN CAST(serial_number AS BIGINT) END ASC NULLS LAST, " \
        "serial_number ASC NULLS LAST, created_at ASC, id ASC"
      )
    )
  }

  def self.ensure_structured_code_columns_loaded!
    return if (STRUCTURED_ASSET_CODE_COLUMNS - attribute_names).empty?

    reset_column_information
  end

  def self.next_generated_serial_number
    latest_numeric_serial = where("serial_number ~ '^[0-9]+$'")
      .order(Arel.sql("CAST(serial_number AS BIGINT) DESC"))
      .limit(1)
      .pick(:serial_number)

    latest_numeric_serial.to_i + 1
  end

  def self.financial_year_label(code_date)
    return "" if code_date.blank?

    start_year = code_date.month >= 4 ? code_date.year : code_date.year - 1
    end_year = start_year + 1
    "#{start_year}-#{end_year}"
  end

  private

  def normalize_asset_code_inputs
    self.name = name.to_s.strip.presence
    self.serial_number = serial_number.to_s.strip.presence
    self.unique_product_code = unique_product_code.to_s.strip.presence
  end

  def normalize_insurance_inputs
    self.insurance_company_name = insurance_company_name.to_s.strip.presence
    self.insurance_policy_number = insurance_policy_number.to_s.strip.presence
  end

  def assign_default_serial_number
    return if serial_number.present?

    self.serial_number = self.class.next_generated_serial_number.to_s
  end

  def assign_default_item_code_from_product
    return if unique_product_code.present?

    self.unique_product_code = product&.product_code.to_s.strip.presence
  end

  def clear_insurance_details_unless_insured
    return if insured?

    self.insurance_date = nil
    self.insurance_company_name = nil
    self.insurance_policy_number = nil
    self.insurance_expiry_date = nil
  end

  def insurance_expiry_date_must_follow_insurance_date
    return if insurance_date.blank? || insurance_expiry_date.blank?
    return unless insurance_expiry_date < insurance_date

    errors.add(:insurance_expiry_date, "must be on or after the insurance date")
  end

  def assign_asset_code
    return unless structured_asset_code_ready?

    self.asset_code = self.class.generate_asset_code(
      stakeholder_name: stakeholder_category.name,
      primary_location: primary_office_category.asset_code_segment,
      secondary_location: secondary_office_category.asset_code_segment,
      product_type_code: product.asset_product_type_code_segment,
      item_number: unique_product_code,
      code_date: asset_code_date
    )
  end

  def structured_asset_code_required?
    new_record? ||
      stakeholder_category_id.present? ||
      primary_office_category_id.present? ||
      secondary_office_category_id.present? ||
      asset_code_date.present?
  end

  def structured_asset_code_ready?
    stakeholder_category.present? &&
      primary_office_category.present? &&
      secondary_office_category.present? &&
      product.present? &&
      asset_code_date.present? &&
      unique_product_code.present?
  end

  def office_categories_belong_to_selected_stakeholder
    if primary_office_category.present? && primary_office_category.stakeholder_category_id != stakeholder_category_id
      errors.add(:primary_office_category_id, "must belong to the selected stakeholder")
    end

    if secondary_office_category.present? && secondary_office_category.stakeholder_category_id != stakeholder_category_id
      errors.add(:secondary_office_category_id, "must belong to the selected stakeholder")
    end
  end

  def office_locations_must_differ
    return if primary_office_category_id.blank? || secondary_office_category_id.blank?
    return unless primary_office_category_id == secondary_office_category_id

    errors.add(:secondary_office_category_id, "must be different from the first location")
  end

  def self.generate_asset_code(stakeholder_name:, primary_location:, secondary_location:, product_type_code:, item_number:, code_date:)
    [
      normalize_asset_code_segment(stakeholder_name),
      normalize_asset_code_segment(primary_location),
      normalize_asset_code_segment(secondary_location),
      normalize_asset_code_segment(product_type_code),
      normalize_asset_code_segment(item_number),
      asset_code_date_segment(code_date),
      financial_year_label(code_date)
    ].join("/")
  end

  def self.asset_code_date_segment(code_date)
    "Dt.#{code_date.strftime("%d.%m.%Y")}"
  end

  public

  def insurance_pending?
    insured.nil?
  end

  def insurance_status_label
    return "Yes" if insured?
    return "No" if insured == false

    "Pending"
  end

  def insurance_status_css_class
    return "asset-insurance-badge asset-insurance-badge--yes" if insured?
    return "asset-insurance-badge asset-insurance-badge--no" if insured == false

    "asset-insurance-badge asset-insurance-badge--pending"
  end

  def self.normalize_asset_code_segment(value)
    value.to_s.strip
         .gsub("/", "-")
         .gsub(/\s*-\s*/, "-")
         .gsub(/\s+/, " ")
  end
end
