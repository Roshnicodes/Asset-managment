class VendorSelectionCriterion < ApplicationRecord
  self.table_name = "vendor_selection_criteria"

  belongs_to :theme
  has_many :quotation_proposal_criteria_selections, dependent: :nullify

  validates :theme, presence: true
  validates :criteria, presence: true
end
