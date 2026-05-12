class QuotationProposalVendorInvoiceRequest < ApplicationRecord
  TOKEN_LENGTH = 12
  STATUSES = %w[pending_invoice uploaded accepted returned].freeze
  TRANSACTION_TYPES = ["NEFT", "RTGS", "IMPS", "UPI", "Cheque", "Cash", "Bank Transfer", "Other"].freeze

  belongs_to :quotation_proposal_vendor
  belongs_to :maker_reviewed_by, class_name: "EmployeeMaster", optional: true
  belongs_to :payment_reference_marked_by, class_name: "EmployeeMaster", optional: true
  belongs_to :payment_advice_updated_by, class_name: "EmployeeMaster", optional: true

  has_many_attached :vendor_invoices
  has_many :assets, dependent: :nullify

  serialize :item_snapshot, coder: JSON

  before_validation :assign_request_token, on: :create

  validates :request_token, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent_first, -> { order(requested_at: :desc, created_at: :desc) }

  def ensure_request_token!
    return request_token if request_token.present?

    update!(request_token: generate_unique_token)
    request_token
  end

  def uploaded?
    status == "uploaded"
  end

  def accepted?
    status == "accepted"
  end

  def returned?
    status == "returned"
  end

  def pending_invoice?
    status == "pending_invoice"
  end

  def awaiting_vendor_upload?
    pending_invoice? || returned?
  end

  def awaiting_maker_review?
    uploaded?
  end

  def assets_created?
    assets_created_at.present? || assets.exists?
  end

  def payment_reference_assigned?
    pdo_no.present? && rfp_no.present? && rfp_created_on.present?
  end

  def payment_advice_pending?
    payment_reference_assigned? && payment_advice_sent_at.blank?
  end

  def payment_advised?
    payment_advice_sent_at.present?
  end

  def finance_transaction_recorded?
    finance_transaction_type_value.present? && finance_transaction_no_value.present? && finance_transaction_date_value.present?
  end

  def payment_transaction_type
    finance_transaction_type_value.presence || (utr_no.present? || asa_bank_name.present? ? "Bank Transfer" : nil)
  end

  def payment_transaction_no
    finance_transaction_no_value.presence || utr_no.presence
  end

  def payment_transaction_date
    finance_transaction_date_value || utr_date
  end

  def legacy_payment_advice_details?
    (utr_no.present? || utr_date.present? || asa_bank_name.present? || asa_account_no.present?) && !finance_transaction_recorded?
  end

  def snapshot_items
    Array(item_snapshot).map(&:with_indifferent_access)
  end

  def received_quantity_total
    snapshot_items.sum { |item| item[:received_quantity].to_d }
  end

  private

  def finance_transaction_type_value
    read_optional_attribute(:transaction_type)
  end

  def finance_transaction_no_value
    read_optional_attribute(:transaction_no)
  end

  def finance_transaction_date_value
    read_optional_attribute(:transaction_date)
  end

  def read_optional_attribute(attribute_name)
    return unless has_attribute?(attribute_name.to_s)

    self[attribute_name]
  end

  def assign_request_token
    self.request_token = generate_unique_token if request_token.blank?
  end

  def generate_unique_token
    loop do
      token = SecureRandom.alphanumeric(TOKEN_LENGTH)
      break token unless self.class.exists?(request_token: token)
    end
  end
end
