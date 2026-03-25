class QuotationProposalVendor < ApplicationRecord
  belongs_to :quotation_proposal
  belongs_to :vendor_registration
end
