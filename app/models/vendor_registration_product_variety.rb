class VendorRegistrationProductVariety < ApplicationRecord
  belongs_to :vendor_registration
  belongs_to :product_variety
end
