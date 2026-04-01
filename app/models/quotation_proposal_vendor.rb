class QuotationProposalVendor < ApplicationRecord
  belongs_to :quotation_proposal
  belongs_to :vendor_registration
  has_many :vendor_items, class_name: "QuotationProposalVendorItem", dependent: :destroy
  has_one :vendor_dispatch, class_name: "QuotationVendorDispatch", dependent: :destroy

  accepts_nested_attributes_for :vendor_items

  RESPONSE_STATUSES = %w[pending responded].freeze

  validates :qr_token, uniqueness: true, allow_nil: true
  validates :response_status, inclusion: { in: RESPONSE_STATUSES }, allow_blank: true

  scope :responded, -> { where(response_status: "responded") }

  def ensure_qr_token!
    return qr_token if qr_token.present?

    update!(qr_token: generate_unique_qr_token, qr_generated_at: Time.current)
    qr_token
  end

  def total_quoted_amount
    vendor_items.sum { |item| item.line_total || 0 }
  end

  def total_gst_amount
    vendor_items.sum { |item| item.gst_amount || 0 }
  end

  def grand_total_amount
    vendor_items.sum { |item| item.grand_total || 0 }
  end

  def response_submitted?
    response_status == "responded"
  end

  def comparable?
    response_submitted?
  end

  def dispatch_record!
    vendor_dispatch || create_vendor_dispatch!(
      quotation_proposal: quotation_proposal,
      vendor_registration: vendor_registration,
      user: quotation_proposal.user,
      stakeholder_category: quotation_proposal.theme&.stakeholder_category,
      vendor_name: vendor_registration.display_name,
      mobile_no: vendor_registration.mobile_no,
      sent_at: Time.current,
      status: "sent"
    )
  end

  private

  def generate_unique_qr_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless self.class.exists?(qr_token: token)
    end
  end
end
