class QuotationProposalItem < ApplicationRecord
  belongs_to :quotation_proposal
  belongs_to :unit

  validates :item_name, :quantity, :remark, :unit, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :max_rate, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
end
