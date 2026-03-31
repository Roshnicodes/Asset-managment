class QuotationVendorOtp < ApplicationRecord
  belongs_to :quotation_vendor_dispatch
  belongs_to :quotation_proposal
  belongs_to :vendor_registration

  validates :otp_code, :mobile_no, presence: true
end
