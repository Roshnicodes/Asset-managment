class QuotationProposal < ApplicationRecord
  class VendorDispatchError < StandardError; end

  WORKFLOW_STATUSES = %w[
    committee_pending
    committee_approved
    sent_to_vendors
    responses_received
    vendor_selected
    returned
    rejected
  ].freeze

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
    return approval_request.current_step if approval_request.present?

    committee_steps.ordered.find_by(status: "pending")
  end

  def committee_completed?
    return approval_request.status == "approved" if approval_request.present?

    committee_steps.exists? && committee_steps.all? { |step| step.status == "approved" }
  end

  def committee_member?(employee)
    return false unless employee

    committee_approver_ids.include?(employee.id)
  end

  def committee_user?(user)
    return false unless user&.email.present?

    lookup_email = user.email.to_s.strip.downcase
    committee_employee_scope.any? do |step|
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
    if approval_request.present?
      approval_request.approve!(employee: employee, remark: remark)
      approved_step = approval_request.approval_steps.find_by(employee_master: employee, status: "approved")
      return [approved_step, approval_request.current_step]
    end

    step = committee_steps.find_by!(employee_master: employee, status: "pending")
    step.approve!(remark: remark)
    refresh_response_status!
    [step, nil]
  end

  def return_committee_step!(employee:, remark:)
    if approval_request.present?
      approval_request.return_to_employee!(employee: employee, remark: remark)
      return approval_request.approval_steps.find_by(employee_master: employee, status: "returned")
    end

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
      ensure_vendor_dispatch_ready!(dispatch)

      sent = QuotationVendorSmsGateway.send_vendor_link(dispatch)
      raise VendorDispatchError, vendor_dispatch_failure_message(dispatch) unless sent

      dispatch.update!(
        sent_at: Time.current,
        status: "sent",
        access_granted: false,
        access_expires_at: nil,
        otp_verified_at: nil
      )
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
    elsif approval_request&.status == "approved"
      "committee_approved"
    elsif approval_request&.status == "rejected"
      "rejected"
    elsif approval_request&.employee_return_pending? || approval_request&.level_return_pending? || approval_request&.status == "returned"
      "returned"
    elsif approval_request.present?
      "committee_pending"
    elsif committee_completed?
      "committee_approved"
    elsif committee_steps.where(status: "returned").exists?
      "returned"
    else
      "committee_pending"
    end

    update_column(:workflow_status, new_status) if persisted? && workflow_status != new_status
  end

  def bootstrap_approval_request_from_committee!
    return approval_request if approval_request.present?

    form_name, approval_channel = resolve_quotation_approval_channel_for_request!
    return nil unless approval_channel

    created_request = nil

    transaction do
      created_request = create_approval_request!(
        approval_channel: approval_channel,
        form_name: form_name,
        status: "pending",
        current_level: committee_steps.minimum(:level)
      )

      rebuild_approval_request_steps!
    end

    created_request
  rescue ActiveRecord::RecordInvalid
    created_request&.destroy if created_request&.persisted?
    nil
  end

  def rebuild_approval_request_steps!
    raise ActiveRecord::RecordNotFound, "Approval request is missing" if approval_request.blank?

    transaction do
      existing_steps = approval_request.approval_steps.index_by(&:level)
      committee_steps.ordered.each do |committee_step|
        approval_step = existing_steps.delete(committee_step.level) || approval_request.approval_steps.build(level: committee_step.level)

        approval_step.assign_attributes(
          employee_master: committee_step.employee_master,
          from_user: previous_committee_member_for(committee_step.level),
          previous_action: committee_step.level == 1 ? "NA" : "L#{committee_step.level - 1} Approval",
          current_action: "L#{committee_step.level} Approval",
          status: "pending",
          remark: nil,
          actioned_at: nil
        )
        approval_step.save!
      end

      existing_steps.values.each(&:destroy!)

      approval_request.update!(
        current_level: committee_steps.minimum(:level),
        status: "pending",
        return_mode: nil,
        returned_by_level: nil,
        returned_to_level: nil
      )
    end

    sync_committee_steps_from_approval_request!
    refresh_response_status!
  end

  def approval_request_backed_by_committee_steps?
    return false unless approval_request.present?

    committee_entries = committee_steps.ordered.to_a
    committee_levels = committee_entries.map(&:level)
    request_steps = approval_request.approval_steps.order(:level).to_a
    return false unless request_steps.map(&:level) == committee_levels

    request_steps.zip(committee_entries).all? do |request_step, committee_step|
      request_step.employee_master_id == committee_step.employee_master_id &&
        request_step.current_action.to_s == "L#{request_step.level} Approval" &&
        request_step.previous_action.to_s == (request_step.level == 1 ? "NA" : "L#{request_step.level - 1} Approval")
    end
  end

  def backfill_approval_request_steps_from_committee!
    raise ActiveRecord::RecordNotFound, "Approval request is missing" if approval_request.blank?

    committee_entries = committee_steps.ordered.to_a

    transaction do
      existing_steps = approval_request.approval_steps.index_by(&:level)
      committee_entries.each do |committee_step|
        approval_step = existing_steps.delete(committee_step.level) || approval_request.approval_steps.build(level: committee_step.level)
        derived_status = derived_approval_status_from_committee(committee_step)

        approval_step.assign_attributes(
          employee_master: committee_step.employee_master,
          from_user: previous_committee_member_for(committee_step.level),
          previous_action: committee_step.level == 1 ? "NA" : "L#{committee_step.level - 1} Approval",
          current_action: "L#{committee_step.level} Approval",
          status: derived_status,
          remark: %w[approved returned rejected].include?(derived_status) ? committee_step.remark : nil,
          actioned_at: %w[approved returned rejected].include?(derived_status) ? committee_step.actioned_at : nil
        )
        approval_step.save!
      end

      existing_steps.values.each(&:destroy!)

      returned_step = approval_request.approval_steps.find_by(status: "returned")
      rejected_step = approval_request.approval_steps.find_by(status: "rejected")
      pending_step = approval_request.approval_steps.find_by(status: "pending")

      approval_request.update!(
        current_level: pending_step&.level,
        status: rejected_step.present? ? "rejected" : returned_step.present? ? "returned" : pending_step.present? ? "pending" : "approved",
        return_mode: returned_step.present? ? "employee" : nil,
        returned_by_level: returned_step&.level,
        returned_to_level: nil
      )
    end

    apply_approval_request_steps_to_committee!
    refresh_response_status!
  end

  def sync_committee_steps_from_approval_request!
    return unless approval_request.present?

    backfill_approval_request_steps_from_committee! unless approval_request_backed_by_committee_steps?
    apply_approval_request_steps_to_committee!
    refresh_response_status!
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

  def ensure_vendor_dispatch_ready!(dispatch)
    return if dispatch.mobile_no.present?

    vendor_name = dispatch.vendor_name.to_s.strip.presence || "Selected vendor"
    raise VendorDispatchError, "#{vendor_name} does not have a registered mobile number."
  end

  def vendor_dispatch_failure_message(dispatch)
    vendor_name = dispatch.vendor_name.to_s.strip.presence || "the selected vendor"
    mobile_no = dispatch.mobile_no.to_s.strip.presence || "the registered mobile number"

    "SMS could not be sent to #{vendor_name} on #{mobile_no}. Please verify the SMS setup and try again."
  end

  def resolve_quotation_approval_channel_for_request!
    ["Quotation Proposal", "Quotation Request"].each do |form_name|
      approval_channel = ApprovalRequestBuilder.approval_channel_for(self, form_name: form_name)
      return [form_name, approval_channel] if approval_channel.present?
    end

    ["Quotation Proposal", ensure_generated_quotation_approval_channel!]
  end

  def ensure_generated_quotation_approval_channel!
    ApprovalChannel.create!(
      form_name: "Quotation Proposal",
      approval_type: "Sequential",
      theme: theme,
      stakeholder_category_id: stakeholder_category_id,
      approval_channel_steps_attributes: committee_steps.ordered.map do |committee_step|
        {
          step_number: committee_step.level,
          from_user_id: previous_committee_member_for(committee_step.level)&.id,
          previous_action: committee_step.level == 1 ? "NA" : "L#{committee_step.level - 1} Approval",
          current_action: "L#{committee_step.level} Approval",
          to_responsible_user_id: committee_step.employee_master_id
        }
      end
    )
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    ApprovalChannel
      .includes(:approval_channel_steps)
      .where(form_name: "Quotation Proposal", theme_id: theme_id, stakeholder_category_id: stakeholder_category_id)
      .detect { |channel| channel.flow_steps.any? }
  end

  def committee_approver_ids
    if approval_request.present?
      approval_request.approval_steps.pluck(:employee_master_id)
    else
      committee_steps.pluck(:employee_master_id)
    end
  end

  def committee_employee_scope
    if approval_request.present?
      approval_request.approval_steps.includes(:employee_master)
    else
      committee_steps.includes(:employee_master)
    end
  end

  def previous_committee_member_for(level)
    committee_steps.find { |step| step.level == level - 1 }&.employee_master
  end

  def map_approval_status_to_committee_status(status)
    case status.to_s
    when "approved"
      "approved"
    when "returned"
      "returned"
    when "rejected"
      "rejected"
    when "pending"
      "pending"
    else
      "waiting"
    end
  end

  def derived_approval_status_from_committee(committee_step)
    return committee_step.status if committee_step.status.in?(ApprovalStep::STATUSES)

    "waiting"
  end

  def apply_approval_request_steps_to_committee!
    steps_by_level = approval_request.trail_steps.index_by(&:level)

    committee_steps.ordered.each do |committee_step|
      trail_step = steps_by_level[committee_step.level]
      next unless trail_step&.employee_master.present?

      updates = {
        employee_master_id: trail_step.employee_master.id,
        status: map_approval_status_to_committee_status(trail_step.effective_status),
        remark: trail_step.remark,
        actioned_at: trail_step.actioned_at
      }

      committee_step.update!(updates) if committee_step.slice(:employee_master_id, :status, :remark, :actioned_at).symbolize_keys != updates
    end
  end

  def approval_request_status_matches_steps?(request_steps)
    pending_count = request_steps.count { |step| step.status == "pending" }
    returned_count = request_steps.count { |step| step.status == "returned" }
    rejected_count = request_steps.count { |step| step.status == "rejected" }

    case approval_request.status
    when "pending"
      pending_count.positive? && returned_count.zero? && rejected_count.zero?
    when "approved"
      request_steps.present? && request_steps.all? { |step| step.status == "approved" }
    when "returned"
      returned_count == 1 && pending_count.zero? && rejected_count.zero?
    when "rejected"
      rejected_count == 1 && pending_count.zero? && returned_count.zero?
    else
      false
    end
  end

  def normalized_step_remark(step)
    actionable_status = step.respond_to?(:effective_status) ? step.effective_status : step.status
    return "" unless actionable_status.in?(%w[approved returned rejected])

    step.remark.to_s.strip
  end

  def normalized_step_action_time(step)
    actionable_status = step.respond_to?(:effective_status) ? step.effective_status : step.status
    return nil unless actionable_status.in?(%w[approved returned rejected])

    step.actioned_at&.to_i
  end

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
