class QuotationProposalVendor < ApplicationRecord
  SMS_TOKEN_LENGTH = 12

  belongs_to :quotation_proposal
  belongs_to :vendor_registration
  belongs_to :purchase_order_authorized_by, class_name: "EmployeeMaster", optional: true
  belongs_to :purchase_order_reply_updated_by, class_name: "EmployeeMaster", optional: true
  has_many :vendor_items, class_name: "QuotationProposalVendorItem", dependent: :destroy
  has_one :vendor_dispatch, class_name: "QuotationVendorDispatch", dependent: :destroy
  has_many :committee_member_scores, class_name: "QuotationProposalVendorScore", dependent: :destroy
  has_many :purchase_order_activities, class_name: "QuotationProposalVendorPoActivity", dependent: :destroy
  has_many :invoice_requests, class_name: "QuotationProposalVendorInvoiceRequest", dependent: :destroy
  has_many_attached :vendor_documents

  accepts_nested_attributes_for :vendor_items

  RESPONSE_STATUSES = %w[pending responded].freeze
  PURCHASE_ORDER_STATUSES = %w[draft sent accepted returned rejected].freeze

  validates :qr_token, uniqueness: true, allow_nil: true
  validates :po_token, uniqueness: true, allow_nil: true
  validates :response_status, inclusion: { in: RESPONSE_STATUSES }, allow_blank: true
  validates :purchase_order_status, inclusion: { in: PURCHASE_ORDER_STATUSES }, allow_blank: true

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

  def ensure_po_token!
    return po_token if sms_friendly_token?(po_token)

    update!(po_token: generate_unique_token_for(:po_token))
    po_token
  end

  def purchase_order_sent?
    purchase_order_status.in?(%w[sent accepted returned rejected])
  end

  def purchase_order_pending_vendor_action?
    purchase_order_status == "sent"
  end

  def purchase_order_expired?
    purchase_order_due_date.present? && purchase_order_due_date < Date.current
  end

  def purchase_order_returned_once?
    if purchase_order_activities.loaded?
      purchase_order_activities.any? { |activity| activity.action_type == "vendor_returned" }
    else
      purchase_order_activities.where(action_type: "vendor_returned").exists?
    end
  end

  def pending_invoice_requests?
    if invoice_requests.loaded?
      invoice_requests.any? { |request| request.status == "pending_invoice" }
    else
      invoice_requests.where(status: "pending_invoice").exists?
    end
  end

  def add_purchase_order_activity!(action_type:, actor_name:, actor_role:, note: nil, employee_master: nil, user: nil, occurred_at: Time.current)
    purchase_order_activities.create!(
      action_type: action_type,
      actor_name: actor_name,
      actor_role: actor_role,
      note: note.presence,
      employee_master: employee_master,
      user: user,
      occurred_at: occurred_at
    )
  end

  def score_for(employee)
    return unless employee

    if committee_member_scores.loaded?
      committee_member_scores.find { |record| record.employee_master_id == employee.id }&.score
    else
      committee_member_scores.find_by(employee_master_id: employee.id)&.score
    end
  end

  def committee_score_value
    if committee_member_scores.loaded?
      scores = committee_member_scores.filter_map(&:score)
      return committee_score if scores.empty?

      scores.sum
    else
      return committee_score unless committee_member_scores.exists?

      committee_member_scores.sum(:score)
    end
  end

  def committee_score_count
    if committee_member_scores.loaded?
      committee_member_scores.count { |record| record.score.present? }
    else
      committee_member_scores.where.not(score: nil).count
    end
  end

  def sync_cached_committee_score!
    return if destroyed?

    update_column(:committee_score, committee_member_scores.where.not(score: nil).sum(:score).presence)
  end

  def dispatch_record!
    ensure_vendor_item_rows!

    dispatch = vendor_dispatch || build_vendor_dispatch
    dispatch.assign_attributes(
      quotation_proposal: quotation_proposal,
      vendor_registration: vendor_registration,
      user: quotation_proposal.user,
      stakeholder_category: vendor_registration.stakeholder_category || quotation_proposal.theme&.stakeholder_category,
      vendor_name: vendor_registration.display_name,
      mobile_no: vendor_registration.mobile_no
    )
    dispatch.status = "pending" if dispatch.new_record?
    dispatch.save! if dispatch.new_record? || dispatch.changed?
    dispatch
  end

  def ensure_vendor_item_rows!
    proposal_item_ids = quotation_proposal.quotation_proposal_items.pluck(:id)
    existing_item_ids = vendor_items.pluck(:quotation_proposal_item_id)

    (proposal_item_ids - existing_item_ids).each do |item_id|
      vendor_items.create!(quotation_proposal_item_id: item_id)
    end

    vendor_items.where.not(quotation_proposal_item_id: proposal_item_ids).destroy_all
  end

  private

  def sms_friendly_qr_token?
    sms_friendly_token?(qr_token)
  end

  def sms_friendly_token?(token)
    token.present? && token.match?(/\A[a-zA-Z0-9]{1,#{SMS_TOKEN_LENGTH}}\z/)
  end

  def generate_unique_qr_token
    generate_unique_token_for(:qr_token)
  end

  def generate_unique_token_for(attribute_name)
    loop do
      token = SecureRandom.alphanumeric(SMS_TOKEN_LENGTH)
      break token unless self.class.exists?(attribute_name => token)
    end
  end
end
