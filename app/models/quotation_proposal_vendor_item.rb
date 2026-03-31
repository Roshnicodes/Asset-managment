class QuotationProposalVendorItem < ApplicationRecord
  belongs_to :quotation_proposal_vendor
  belongs_to :quotation_proposal_item

  validates :quotation_proposal_item_id, uniqueness: { scope: :quotation_proposal_vendor_id }
  validates :quoted_rate, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :gst_percentage, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

  delegate :item_name, :quantity, :unit, to: :quotation_proposal_item

  def line_total
    return nil if quoted_rate.blank?

    quoted_rate.to_d * quotation_proposal_item.quantity.to_d
  end

  def gst_amount
    return 0.to_d if line_total.blank? || gst_percentage.blank?

    (line_total * gst_percentage.to_d) / 100
  end

  def cgst_amount
    gst_amount / 2
  end

  def sgst_amount
    gst_amount / 2
  end

  def grand_total
    return 0.to_d if line_total.blank?

    line_total + gst_amount
  end
end
