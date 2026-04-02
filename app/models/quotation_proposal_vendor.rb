class QuotationProposalVendor < ApplicationRecord
  SMS_TOKEN_LENGTH = 12

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
    return qr_token if sms_friendly_qr_token?

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
    dispatch = vendor_dispatch || build_vendor_dispatch
    dispatch.assign_attributes(
      quotation_proposal: quotation_proposal,
      vendor_registration: vendor_registration,
      user: quotation_proposal.user,
      stakeholder_category: quotation_proposal.theme&.stakeholder_category,
      vendor_name: vendor_registration.display_name,
      mobile_no: vendor_registration.mobile_no
    )
    dispatch.status = "pending" if dispatch.new_record?
    dispatch.save! if dispatch.new_record? || dispatch.changed?
    dispatch
  end

  private

  def sms_friendly_qr_token?
    qr_token.present? && qr_token.match?(/\A[a-zA-Z0-9]{1,#{SMS_TOKEN_LENGTH}}\z/)
  end

  def generate_unique_qr_token
    loop do
      token = SecureRandom.alphanumeric(SMS_TOKEN_LENGTH)
      break token unless self.class.exists?(qr_token: token)
    end
  end
end
