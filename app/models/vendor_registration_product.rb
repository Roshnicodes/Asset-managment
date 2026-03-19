class VendorRegistrationProduct < ApplicationRecord
  belongs_to :vendor_registration
  belongs_to :product
end
