class QuotationProposalItem < ApplicationRecord
  belongs_to :quotation_proposal
  belongs_to :unit

  validates :item_name, :quantity, :unit, presence: true
  validates :quantity, numericality: { greater_than: 0 }
end
