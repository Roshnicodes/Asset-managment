class VendorBankMaster < ApplicationRecord
  belongs_to :vendor_registration

  ACCOUNT_TYPES = ["Current", "Saving"].freeze

  validates :bank_name, :ifsc_code, :account_number, :account_type, presence: true
end
