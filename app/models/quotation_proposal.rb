class QuotationProposal < ApplicationRecord
  WORKFLOW_STATUSES = %w[committee_pending committee_approved sent_to_vendors responses_received vendor_selected returned].freeze

  belongs_to :theme
  belongs_to :user, optional: true
  belongs_to :selected_vendor_registration, class_name: "VendorRegistration", optional: true

  has_many :quotation_proposal_vendors, dependent: :destroy
  has_many :vendor_registrations, through: :quotation_proposal_vendors, validate: false
  has_many :quotation_proposal_items, dependent: :destroy, inverse_of: :quotation_proposal
  has_many :committee_steps, -> { order(:level) }, class_name: "QuotationProposalCommitteeStep", dependent: :destroy, inverse_of: :quotation_proposal
  has_one :approval_request, as: :approvable, dependent: :destroy

  accepts_nested_attributes_for :quotation_proposal_items, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :committee_steps, allow_destroy: true, reject_if: proc { |attributes| attributes["employee_master_id"].blank? }

  validates :subject, :proposal_end_date, :theme, presence: true
  validates :workflow_status, inclusion: { in: WORKFLOW_STATUSES }
  validate :must_have_at_least_one_vendor
  validate :must_have_at_least_one_item
  validate :must_have_all_committee_levels

  after_commit :sync_vendor_item_rows, on: %i[create update]

  def display_name
    subject
  end

  def stakeholder_category_id
    theme&.stakeholder_category_id
  end

  def generate_vendor_qr_tokens!
    quotation_proposal_vendors.find_each(&:ensure_qr_token!)
  end

  def current_committee_step
    committee_steps.ordered.find_by(status: "pending")
  end

  def committee_completed?
    committee_steps.exists? && committee_steps.all? { |step| step.status == "approved" }
  end

  def committee_member?(employee)
    return false unless employee

    committee_steps.any? { |step| step.employee_master_id == employee.id }
  end

  def committee_user?(user)
    return false unless user&.email.present?

    lookup_email = user.email.to_s.strip.downcase
    committee_steps.includes(:employee_master).any? do |step|
      step.employee_master&.email_id.to_s.strip.downcase == lookup_email
    end
  end

  def vendor_responses_received?
    quotation_proposal_vendors.responded.exists?
  end

  def normalize_committee_steps!
    committee_steps.ordered.each do |step|
      next if %w[approved returned].include?(step.status)
      step.update_column(:status, "pending") if step.status != "pending"
    end
  end

  def approve_committee_step!(employee:, remark: nil)
    step = committee_steps.find_by!(employee_master: employee, status: "pending")
    step.approve!(remark: remark)
    refresh_response_status!
    [step, nil]
  end

  def return_committee_step!(employee:, remark:)
    step = committee_steps.find_by!(employee_master: employee, status: "pending")
    step.return!(remark: remark)
    committee_steps.where.not(id: step.id).where(status: "waiting").update_all(status: "waiting")
    refresh_response_status!
    step
  end

  def send_to_vendors!
    generate_vendor_qr_tokens!
    quotation_proposal_vendors.includes(:vendor_registration).find_each do |proposal_vendor|
      dispatch = proposal_vendor.dispatch_record!
      dispatch.update!(sent_at: Time.current, status: "sent", access_granted: false, access_expires_at: nil, otp_verified_at: nil)
      QuotationVendorSmsGateway.send_vendor_link(dispatch)
    end
    update!(sent_to_vendors_at: Time.current)
    refresh_response_status!
  end

  def refresh_response_status!
    new_status = if selected_vendor_registration_id.present?
      "vendor_selected"
    elsif quotation_proposal_vendors.responded.exists?
      "responses_received"
    elsif sent_to_vendors_at.present?
      "sent_to_vendors"
    elsif committee_completed?
      "committee_approved"
    elsif committee_steps.where(status: "returned").exists?
      "returned"
    else
      "committee_pending"
    end

    update_column(:workflow_status, new_status) if persisted? && workflow_status != new_status
  end

  def recalculate_vendor_rankings!
    comparable_vendors, pending_vendors = quotation_proposal_vendors.includes(:vendor_items).partition(&:comparable?)
    scored_vendors, unscored_vendors = comparable_vendors.partition { |proposal_vendor| proposal_vendor.committee_score.present? }

    ranked_vendors = scored_vendors.sort_by do |proposal_vendor|
      [
        -proposal_vendor.committee_score.to_i,
        proposal_vendor.grand_total_amount.to_d,
        proposal_vendor.total_quoted_amount.to_d,
        proposal_vendor.id
      ]
    end

    ranked_vendors.each_with_index do |proposal_vendor, index|
      proposal_vendor.update_column(:rank_position, index + 1)
    end

    (pending_vendors + unscored_vendors).each do |proposal_vendor|
      proposal_vendor.update_column(:rank_position, nil)
    end
  end

  private

  def must_have_at_least_one_vendor
    errors.add(:base, "Select at least one vendor.") if vendor_registrations.blank?
  end

  def must_have_at_least_one_item
    kept_items = quotation_proposal_items.reject(&:marked_for_destruction?)
    errors.add(:base, "Add at least one item.") if kept_items.empty?
  end

  def must_have_all_committee_levels
    kept_steps = committee_steps.reject(&:marked_for_destruction?)
    levels = kept_steps.map(&:level).compact.sort
    errors.add(:base, "Committee me L1 se L4 tak sab levels required hain.") if levels != [1, 2, 3, 4]
  end

  def sync_vendor_item_rows
    return unless persisted?

    proposal_item_ids = quotation_proposal_items.pluck(:id)

    quotation_proposal_vendors.includes(:vendor_items).find_each do |proposal_vendor|
      existing_item_ids = proposal_vendor.vendor_items.pluck(:quotation_proposal_item_id)

      (proposal_item_ids - existing_item_ids).each do |item_id|
        proposal_vendor.vendor_items.create!(quotation_proposal_item_id: item_id)
      end

      proposal_vendor.vendor_items.where.not(quotation_proposal_item_id: proposal_item_ids).destroy_all
    end
  end
end
