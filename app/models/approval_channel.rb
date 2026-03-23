class ApprovalChannel < ApplicationRecord
  belongs_to :stakeholder_category, optional: true

  FORM_NAMES = [
    "Vendor Registration",
    "Product Entry",
    "Product Variety Entry",
    "Vendor Bank Master",
    "Quotation Request",
    "Vendor Quotation Response"
  ].freeze

  APPROVAL_TYPES = ["Sequential", "Parallel"].freeze

  validates :form_name, :approval_type, presence: true
end
