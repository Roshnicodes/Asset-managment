class VendorRegistration < ApplicationRecord
  belongs_to :registration_type
  belongs_to :firm, optional: true
  belongs_to :state
  belongs_to :district
  belongs_to :block
  has_many :vendor_registration_themes, dependent: :destroy
  has_many :themes, through: :vendor_registration_themes
  has_many :vendor_registration_products, dependent: :destroy
  has_many :products, through: :vendor_registration_products
  has_many :vendor_registration_product_varieties, dependent: :destroy
  has_many :product_varieties, through: :vendor_registration_product_varieties
  has_many :vendor_bank_masters, dependent: :destroy

  validates :vendor_name, :email, :mobile_no, :company_status, presence: true

  def display_name
    vendor_name.presence || company_name.presence || "Vendor Registration ##{id}"
  end
end
