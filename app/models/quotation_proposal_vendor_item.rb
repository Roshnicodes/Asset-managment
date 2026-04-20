class QuotationProposalVendorItem < ApplicationRecord
  belongs_to :quotation_proposal_vendor
  belongs_to :quotation_proposal_item
  has_many :assets, dependent: :nullify

  validates :quotation_proposal_item_id, uniqueness: { scope: :quotation_proposal_vendor_id }
  validates :quoted_rate, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :gst_percentage, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
  validates :received_quantity, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true

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

  def pending_quantity
    [quantity.to_d - received_quantity.to_d, 0.to_d].max
  end

  def fully_received?
    pending_quantity <= 0
  end

  def partially_received?
    received_quantity.to_d.positive? && !fully_received?
  end
end
