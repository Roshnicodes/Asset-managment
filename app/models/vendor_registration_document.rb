class VendorRegistrationDocument < ApplicationRecord
  belongs_to :vendor_registration
  belongs_to :document_master

  has_one_attached :file
end
