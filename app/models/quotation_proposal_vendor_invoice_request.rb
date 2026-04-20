class QuotationProposalVendorInvoiceRequest < ApplicationRecord
  TOKEN_LENGTH = 12
  STATUSES = %w[pending_invoice uploaded accepted returned].freeze

  belongs_to :quotation_proposal_vendor
  belongs_to :maker_reviewed_by, class_name: "EmployeeMaster", optional: true

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

  def snapshot_items
    Array(item_snapshot).map(&:with_indifferent_access)
  end

  def received_quantity_total
    snapshot_items.sum { |item| item[:received_quantity].to_d }
  end

  private

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
