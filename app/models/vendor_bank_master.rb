class VendorBankMaster < ApplicationRecord
  belongs_to :stakeholder_category, optional: true
  belongs_to :vendor_registration, optional: true
  has_one_attached :cancelled_cheque

  ACCOUNT_TYPES = ["Current", "Saving"].freeze
  scope :masters, -> { where(vendor_registration_id: nil).order(:bank_name) }

  validates :bank_name, presence: true
  validates :ifsc_code, :account_number, :account_type, presence: true, if: :vendor_registration_id?
end
