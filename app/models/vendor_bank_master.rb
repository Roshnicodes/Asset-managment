class VendorBankMaster < ApplicationRecord
  IFSC_CODE_FORMAT = /\A[A-Z]{4}0[A-Z0-9]{6}\z/.freeze
  ACCOUNT_NUMBER_FORMAT = /\A\d{9,18}\z/.freeze

  belongs_to :stakeholder_category, optional: true
  belongs_to :vendor_registration, optional: true
  has_one_attached :cancelled_cheque

  ACCOUNT_TYPES = ["Current", "Saving"].freeze
  scope :masters, -> { where(vendor_registration_id: nil).order(:bank_name) }

  before_validation :normalize_bank_fields

  validates :bank_name, presence: true
  validates :ifsc_code, :account_number, :account_type, presence: true, if: :vendor_registration_id?
  validates :ifsc_code, format: { with: IFSC_CODE_FORMAT, message: "must be a valid IFSC code" }, allow_blank: true
  validates :account_number, format: { with: ACCOUNT_NUMBER_FORMAT, message: "must be a valid account number" }, allow_blank: true

  private

  def normalize_bank_fields
    self.ifsc_code = ifsc_code.to_s.strip.upcase.presence
    self.account_number = account_number.to_s.gsub(/\D/, "").presence
  end
end
