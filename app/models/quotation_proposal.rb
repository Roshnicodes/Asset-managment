class QuotationProposal < ApplicationRecord
  class VendorDispatchError < StandardError; end
  MIN_COMMITTEE_MEMBERS = 3
  REQUIRED_COMMITTEE_LEVELS = [1, 2, 3].freeze
  DEFAULT_COMMITTEE_MEMBERS = 3
  COMMITTEE_AMOUNT_THRESHOLD = BigDecimal("1000000")
  PROCUREMENT_AMOUNT_BUCKETS = %w[above_10k below_10k].freeze
  MIN_SUBJECT_WORDS = 5
  MAX_SUBJECT_WORDS = 20
  COMMITTEE_CHANNEL_FORM_NAMES = ["Quotation Proposal", "Quotation Request"].freeze

  THEMATIC_HEAD_DECISIONS = %w[committee direct].freeze

  WORKFLOW_STATUSES = %w[
    thematic_head_pending
    committee_pending
    committee_approved
    sent_to_vendors
    responses_received
    vendor_selected
    returned
    rejected
  ].freeze

  # The quotation committee has one maker-selected member and two members
  # determined by the procurement policy. This transient flag lets the model
  # distinguish that controlled structure from the old free-form rows.
  attr_accessor :committee_from_policy, :committee_policy_errors

  # Outcome of the maker's SMS copy of the vendor links after send_to_vendors!:
  # :sent, :partial, :failed, :no_mobile, or nil when no link SMS went out.
  attr_reader :maker_link_copy_status

  belongs_to :theme
  belongs_to :user, optional: true
  belongs_to :reused_from_quotation_proposal, class_name: "QuotationProposal", optional: true
  belongs_to :selected_vendor_registration, class_name: "VendorRegistration", optional: true
  # The Thematic Head chosen by the maker decides whether the request needs
  # committee approval or goes straight to the vendors.
  belongs_to :thematic_head, class_name: "EmployeeMaster", optional: true

  has_many :reused_quotation_proposals,
           class_name: "QuotationProposal",
           foreign_key: :reused_from_quotation_proposal_id,
           dependent: :nullify,
           inverse_of: :reused_from_quotation_proposal
  has_many :quotation_proposal_vendors, dependent: :destroy
  has_many :vendor_registrations, through: :quotation_proposal_vendors, validate: false
  has_many :quotation_proposal_items, dependent: :destroy, inverse_of: :quotation_proposal
  has_many :committee_steps, -> { order(:level) }, class_name: "QuotationProposalCommitteeStep", dependent: :destroy, inverse_of: :quotation_proposal
  has_many :criteria_selections, -> { order(:created_at, :id) }, class_name: "QuotationProposalCriteriaSelection", dependent: :destroy, inverse_of: :quotation_proposal
  has_many :vendor_selection_criteria, through: :criteria_selections
  has_one :approval_request, as: :approvable, dependent: :destroy

  accepts_nested_attributes_for :quotation_proposal_items, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :committee_steps, allow_destroy: true, reject_if: proc { |attributes| attributes["employee_master_id"].blank? }

  validates :subject, :proposal_end_date, :remark, :theme, presence: true
  validates :workflow_status, inclusion: { in: WORKFLOW_STATUSES }
  validates :procurement_amount_bucket, inclusion: { in: PROCUREMENT_AMOUNT_BUCKETS }
  validates :thematic_head, presence: { message: "must be selected" }, on: :create, unless: :reused_from_quotation_proposal_id?
  validates :thematic_head_decision, inclusion: { in: THEMATIC_HEAD_DECISIONS }, allow_nil: true
  validate :subject_has_minimum_words
  validate :must_have_at_least_one_vendor
  validate :must_have_at_least_one_item
  validate :must_have_all_committee_levels
  validate :maker_cannot_be_committee_member
  validate :committee_members_must_be_unique
  validate :selected_vendors_must_match_stakeholder

  after_commit :sync_vendor_item_rows, on: %i[create update]

  def subject_has_minimum_words
    return if subject.blank?

    word_count = subject.to_s.scan(/\b[[:alnum:]]+\b/).size
    return if word_count.between?(MIN_SUBJECT_WORDS, MAX_SUBJECT_WORDS)

    errors.add(:subject, "must be between #{MIN_SUBJECT_WORDS} and #{MAX_SUBJECT_WORDS} words")
  end


  def committee_approval_required?
    committee_approval_required != false
  end

  # Quotations sent through a Thematic Head get their committee from the head.
  def thematic_head_selects_committee?
    thematic_head_id.present?
  end

  def thematic_head_decision_required?
    thematic_head_id.present? && thematic_head_decision.blank?
  end

  def awaiting_thematic_head_decision?
    thematic_head_decision_required? && thematic_head_requested_at.present?
  end

  def thematic_head?(employee_ids)
    thematic_head_id.present? && Array(employee_ids).include?(thematic_head_id)
  end

  def request_thematic_head_decision!
    update_columns(thematic_head_requested_at: Time.current, updated_at: Time.current)
    refresh_response_status!
  end

  # Records the Thematic Head's choice. "committee" uses the 1st member the
  # head picked plus the policy members (COO/Director and Programme Director –
  # Finance); "direct" drops the committee so the request goes to the vendors.
  def record_thematic_head_decision!(decision, first_member_id: nil)
    raise ArgumentError, "Unknown decision" unless decision.in?(THEMATIC_HEAD_DECISIONS)

    if decision == "committee"
      record_committee_decision!(first_member_id)
    else
      transaction do
        committee_steps.destroy_all
        update_columns(
          thematic_head_decision: "direct",
          thematic_head_decided_at: Time.current,
          committee_approval_required: false,
          updated_at: Time.current
        )
      end
    end

    association(:committee_steps).reset
    refresh_response_status!
  end

  def vendor_dispatch_allowed_for_thematic_head?(employee_ids)
    thematic_head_decision == "direct" && thematic_head?(employee_ids)
  end

  def committee_not_required?
    !committee_approval_required?
  end

# Estimated request value is calculated from the item quantity and the
# internal max rate. It is used before vendors respond, which is when the
# committee must be chosen.
def estimated_procurement_amount
  items = quotation_proposal_items.reject(&:marked_for_destruction?)
  return if items.empty? || items.any? { |item| item.quantity.blank? || item.max_rate.blank? }

  items.sum { |item| item.quantity.to_d * item.max_rate.to_d }
end

def committee_amount_at_or_below_threshold?
  amount = estimated_procurement_amount
  amount.present? && amount <= COMMITTEE_AMOUNT_THRESHOLD
end

# Policy members looked up from Employee Master by designation. The form uses
# this to show members 2 and 3 live while the maker enters item rates.
def self.committee_policy_directory
  serialize = ->(employee) { employee && { id: employee.id, name: employee.name, designation: employee.designation.to_s } }

  {
    threshold: COMMITTEE_AMOUNT_THRESHOLD.to_i,
    coo: serialize.call(committee_member_with_designation("COO")),
    director: serialize.call(committee_member_with_designation("Director")),
    finance: serialize.call(programme_director_finance_member)
  }
end

def self.committee_member_with_designation(designation)
  aliases = { "coo" => ["coo", "chief operating officer"] }
  names = aliases.fetch(designation.to_s.downcase, [designation.to_s.downcase])

  EmployeeMaster
    .where("LOWER(TRIM(designation)) IN (?)", names)
    .order(:id)
    .first
end

def self.programme_director_finance_member
  EmployeeMaster
    .where(<<~SQL.squish)
      LOWER(TRIM(designation)) LIKE '%programme%director%finance%'
      OR LOWER(TRIM(designation)) LIKE '%program%director%finance%'
    SQL
    .order(:id)
    .first || EmployeeMaster.where("LOWER(TRIM(designation)) = ?", "senior manager finance").order(:id).first
end

def committee_policy_member(level)
  case level.to_i
  when 2
    committee_amount_at_or_below_threshold? ? committee_member_with_designation("COO") : committee_member_with_designation("Director")
  when 3
    programme_director_finance_member
  end
end

def committee_policy_member_label(level)
  case level.to_i
  when 1 then "Maker-selected member"
  when 2 then committee_amount_at_or_below_threshold? ? "COO (up to ₹10 lakh)" : "Director (above ₹10 lakh)"
  when 3 then "Programme Director – Finance"
  else "Committee Member #{level}"
  end
end

def committee_amount_label
  amount = estimated_procurement_amount
  return "Add item quantity and max rate to calculate" if amount.blank?

  "₹#{amount.to_fs(:delimited, precision: 2)} estimated request value"
end

# Prepares the three controlled rows for rendering without persisting them.
# Member 1 remains editable; member 2 and 3 are always overwritten when the
# proposal is saved so a crafted form submission cannot bypass the policy.
def prepare_committee_policy_steps!
  return clear_committee_steps_for_direct_dispatch! if committee_not_required?

  self.committee_from_policy = true
  self.committee_policy_errors = []
  upsert_committee_policy_steps!
end

# Kept as a compatibility wrapper for the existing controller workflow.
def apply_configured_committee!
  if committee_not_required?
    clear_committee_steps_for_direct_dispatch!
    return true
  end

  # With a Thematic Head the committee is chosen by that head, not by policy.
  # New requests always go through a Thematic Head.
  return true if thematic_head_selects_committee? || new_record?

  prepare_committee_policy_steps!
  committee_policy_errors.blank?
end

  def display_name
    subject
  end

  def approval_locked?
    approval_request&.status == "approved"
  end

  def stakeholder_category_id
    theme&.stakeholder_category_id
  end

  def vendor_matches_stakeholder?(vendor_registration)
    return false if vendor_registration.blank?

    proposal_stakeholder_id = stakeholder_category_id
    return true if proposal_stakeholder_id.blank?

    vendor_stakeholder_id = vendor_registration.stakeholder_category_id
    return true if vendor_stakeholder_id.blank? || vendor_stakeholder_id == proposal_stakeholder_id

    vendor_registration.themes.any? { |theme| theme.stakeholder_category_id == proposal_stakeholder_id }
  end

  def sync_selected_vendor_registration!(vendor_registration)
    vendor_id = vendor_registration&.id
    return if selected_vendor_registration_id == vendor_id

    update_columns(selected_vendor_registration_id: vendor_id, updated_at: Time.current)
  end

  def above_10k?
    procurement_amount_bucket == "above_10k"
  end

  def below_10k?
    procurement_amount_bucket == "below_10k"
  end

  def procurement_amount_bucket_label
    below_10k? ? "Below 10K" : "Above 10K"
  end

  def criteria_based_scoring?
    criteria_selections.any?
  end

  def selected_vendor_selection_criterion_ids
    if criteria_selections.loaded?
      criteria_selections.filter_map(&:vendor_selection_criterion_id)
    else
      criteria_selections.where.not(vendor_selection_criterion_id: nil).pluck(:vendor_selection_criterion_id)
    end
  end

  def selected_criteria_labels
    criteria_selections.map(&:display_label)
  end

  def sync_vendor_selection_criteria!(criterion_ids)
    selected_ids = Array(criterion_ids).reject(&:blank?).map(&:to_i).uniq

    return criteria_selections.destroy_all if theme_id.blank? || selected_ids.empty?

    matched_criteria = VendorSelectionCriterion
      .where(id: selected_ids, theme_id: theme_id)
      .order(:id)

    transaction do
      existing_records = criteria_selections.index_by(&:vendor_selection_criterion_id)

      matched_criteria.each do |criterion|
        selection = existing_records.delete(criterion.id) || criteria_selections.build
        selection.vendor_selection_criterion = criterion
        selection.criterion_label = criterion.criteria.to_s.strip
        selection.save! if selection.new_record? || selection.changed?
      end

      existing_records.values.each(&:destroy!)
    end

    association(:criteria_selections).reset if association(:criteria_selections).loaded?
  end

  def generate_vendor_qr_tokens!
    quotation_proposal_vendors.find_each(&:ensure_qr_token!)
  end

  def current_committee_step
    return approval_request.current_step if approval_request.present?

    committee_steps.ordered.find_by(status: "pending")
  end

  def committee_completed?
    return true if committee_not_required?
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

  def missing_max_rate_items
    quotation_proposal_items.select { |item| item.max_rate.blank? }
  end

  def missing_max_rates?
    missing_max_rate_items.any?
  end

  def all_max_rates_present?
    !missing_max_rates?
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

    if below_10k?
      quotation_proposal_vendors.includes(:vendor_registration).find_each do |proposal_vendor|
        dispatch = proposal_vendor.dispatch_record!
        dispatch.update!(
          sent_at: Time.current,
          status: "sent",
          access_granted: true,
          access_expires_at: 12.hours.from_now,
          otp_verified_at: Time.current
        )
      end
      update!(sent_to_vendors_at: Time.current)
      refresh_response_status!
      return
    end

    maker_copy_results = []
    quotation_proposal_vendors.includes(:vendor_registration).find_each do |proposal_vendor|
      dispatch = proposal_vendor.dispatch_record!
      ensure_vendor_dispatch_ready!(dispatch)

      sent = QuotationVendorSmsGateway.send_vendor_link(dispatch)
      raise VendorDispatchError, vendor_dispatch_failure_message(dispatch) unless sent

      maker_copy_results << send_maker_link_copy(dispatch)

      dispatch.update!(
        sent_at: Time.current,
        status: "sent",
        access_granted: false,
        access_expires_at: nil,
        otp_verified_at: nil
      )
    end
    @maker_link_copy_status = summarize_maker_link_copies(maker_copy_results)
    update!(sent_to_vendors_at: Time.current)
    refresh_response_status!
  end

  def quotation_currently_usable?
    selected_vendor_registration_id.present? &&
      quotation_proposal_vendors.responded.exists? &&
      quotation_valid_until.present? &&
      quotation_valid_until >= Date.current
  end

  def set_quotation_validity_from!(received_at = Time.current)
    received_date = received_at.to_date
    financial_year_end = if received_date.month <= 3
      Date.new(received_date.year, 3, 31)
    else
      Date.new(received_date.year + 1, 3, 31)
    end

    self.quotation_valid_until = financial_year_end
    save!(validate: false)
  end

  def invalidate_quotation_reuse!
    return if quotation_valid_until.blank?

    self.quotation_valid_until = Date.current - 1.day
    save!(validate: false)
  end

  def invalidate_reused_quotations!
    reused_quotation_proposals.find_each do |reused_quotation|
      reused_quotation.invalidate_quotation_reuse!
      reused_quotation.invalidate_reused_quotations!
    end
  end

  def refresh_response_status!
    new_status = if selected_vendor_registration_id.present?
      "vendor_selected"
    elsif awaiting_thematic_head_decision?
      "thematic_head_pending"
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
    comparable_vendors, pending_vendors = quotation_proposal_vendors.includes(:vendor_items, :committee_member_scores).partition(&:comparable?)
    scored_vendors, unscored_vendors = comparable_vendors.partition { |proposal_vendor| proposal_vendor.committee_score_value.present? }

    ranked_vendors = scored_vendors.sort_by do |proposal_vendor|
      [
        -proposal_vendor.committee_score_value.to_i,
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

  def committee_scoring_complete?
    required_scores = committee_steps.size
    return false if required_scores.zero?

    responded_vendors = quotation_proposal_vendors.responded.includes(:committee_member_scores).to_a
    return false if responded_vendors.empty?

    responded_vendors.all? { |proposal_vendor| proposal_vendor.committee_score_count == required_scores }
  end

  def sync_vendor_rankings_and_selection!
    recalculate_vendor_rankings!

    ranked_vendor = committee_scoring_complete? ? quotation_proposal_vendors.find_by(rank_position: 1) : nil
    selectable_vendor = ranked_vendor&.vendor_registration
    selectable_vendor = nil unless vendor_matches_stakeholder?(selectable_vendor)

    quotation_proposal_vendors.update_all(selected: false)

    if ranked_vendor.present? && selectable_vendor.present?
      ranked_vendor.update_column(:selected, true)
      sync_selected_vendor_registration!(selectable_vendor)
    else
      sync_selected_vendor_registration!(nil) if selected_vendor_registration_id.present?
    end

    refresh_response_status!
    association(:quotation_proposal_vendors).reset
    association(:selected_vendor_registration).reset
    ranked_vendor
  end

  private

  # Sends the maker the same link SMS the vendor received, so the maker can
  # track it. A failed copy never stops the vendor dispatch.
  def send_maker_link_copy(dispatch)
    maker_mobile = QuotationVendorSmsGateway.maker_mobile_no_for(user)
    return :no_mobile if maker_mobile.blank?
    return :sent if maker_mobile == QuotationVendorSmsGateway.normalize_mobile_no(dispatch.mobile_no)

    QuotationVendorSmsGateway.send_vendor_link(dispatch, mobile_no: maker_mobile) ? :sent : :failed
  rescue StandardError => error
    Rails.logger.warn("Maker copy of quotation link failed for proposal #{id}: #{error.message}")
    :failed
  end

  def summarize_maker_link_copies(results)
    return if results.empty?
    return :no_mobile if results.all?(:no_mobile)
    return :sent if results.all?(:sent)
    return :failed if results.none?(:sent)

    :partial
  end

  def record_committee_decision!(first_member_id)
    first_member = EmployeeMaster.find_by(id: first_member_id.presence)
    raise ArgumentError, "Please pick the 1st Committee Member from the suggestions list." if first_member.blank?

    committee_steps.each(&:mark_for_destruction)
    committee_steps.build(level: 1, employee_master: first_member, status: "waiting")
    assign_attributes(
      committee_approval_required: true,
      thematic_head_decision: "committee",
      thematic_head_decided_at: Time.current
    )
    prepare_committee_policy_steps!
    if committee_policy_errors.any?
      message = committee_policy_errors.to_sentence
      reload
      raise ArgumentError, message
    end

    save!
  rescue ActiveRecord::RecordInvalid
    message = errors.full_messages.to_sentence
    reload
    raise ArgumentError, message
  end

  def ensure_vendor_dispatch_ready!(dispatch)
    return if dispatch.mobile_no.present?

    vendor_name = dispatch.vendor_name.to_s.strip.presence || "Selected vendor"
    raise VendorDispatchError, "#{vendor_name} does not have a registered mobile number."
  end

  def vendor_dispatch_failure_message(dispatch)
    vendor_name = dispatch.vendor_name.to_s.strip.presence || "the selected vendor"
    mobile_no = dispatch.mobile_no.to_s.strip.presence || "the registered mobile number"
    sms_error = QuotationVendorSmsGateway.last_error_message

    [
      "SMS could not be sent to #{vendor_name} on #{mobile_no}. Please verify the SMS setup and try again.",
      sms_error
    ].compact.join(" ")
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

def clear_committee_steps_for_direct_dispatch!
  committee_steps.each(&:mark_for_destruction)
  self.committee_from_policy = false
  self.committee_policy_errors = []
end

def upsert_committee_policy_steps!
  active_steps = committee_steps.reject(&:marked_for_destruction?)
  selected_first_member = active_steps.find { |step| step.level.to_i == 1 }&.employee_master
  required_members = {
    1 => selected_first_member,
    2 => committee_policy_member(2),
    3 => committee_policy_member(3)
  }

  self.committee_policy_errors = []
  committee_policy_errors << "Select the 1st Committee Member." if required_members[1].blank?
  committee_policy_errors << "COO/Director is not configured in Employee Master." if required_members[2].blank?
  committee_policy_errors << "Programme Director – Finance is not configured in Employee Master." if required_members[3].blank?

  active_steps.each do |step|
    step.mark_for_destruction unless required_members.key?(step.level.to_i)
  end

  required_members.each do |level, member|
    next if member.blank?

    step = active_steps.find { |candidate| candidate.level.to_i == level } ||
      committee_steps.build(level: level, status: "waiting")
    step.assign_attributes(employee_master: member, level: level)
    step.status = "waiting" if step.status.blank?
  end
end

def committee_member_with_designation(designation)
  self.class.committee_member_with_designation(designation)
end

def programme_director_finance_member
  self.class.programme_director_finance_member
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
    vendor_count = selected_vendor_count
    errors.add(:base, "Select at least one vendor.") if vendor_count.zero?
    return unless below_10k?
    return unless vendor_count > 1

    errors.add(:base, "Below 10K me sirf ek vendor select kiya ja sakta hai.")
  end

  # Vendors picked in the form arrive as vendor_registrations, while a reused
  # quotation builds quotation_proposal_vendors directly; count either.
  def selected_vendor_count
    built_vendor_ids = quotation_proposal_vendors.target.select(&:new_record?).map(&:vendor_registration_id)
    (vendor_registrations.map(&:id) + built_vendor_ids).compact.uniq.size
  end

  def must_have_at_least_one_item
    kept_items = quotation_proposal_items.reject(&:marked_for_destruction?)
    errors.add(:base, "Add at least one item.") if kept_items.empty?
  end

  def must_have_all_committee_levels
    return unless committee_approval_required?
    # The committee is chosen later by the Thematic Head.
    return if (thematic_head_selects_committee? || new_record?) && thematic_head_decision != "committee"

    kept_steps = committee_steps.reject(&:marked_for_destruction?)

    if committee_from_policy
      Array(committee_policy_errors).each { |message| errors.add(:base, message) }
      errors.add(:base, "The required committee members could not be prepared.") if kept_steps.empty? && committee_policy_errors.blank?
      return
    end

    levels = kept_steps.map(&:level).compact.sort
    levels_with_members = kept_steps.select { |step| step.employee_master_id.present? }.map(&:level).compact.sort

    if kept_steps.size < MIN_COMMITTEE_MEMBERS
      errors.add(:base, "Committee me kam se kam #{MIN_COMMITTEE_MEMBERS} members required hain.")
      return
    end
    expected_levels = (1..kept_steps.size).to_a
    errors.add(:base, "Committee Member 1 se levels bina gap ke continue hone chahiye.") if levels != expected_levels

    missing_required_levels = REQUIRED_COMMITTEE_LEVELS - levels_with_members
    return if missing_required_levels.empty?

    missing_labels = missing_required_levels.map { |level| WorkflowLevelNaming.humanize_level_label(level) }.join(", ")
    errors.add(:base, "#{missing_labels} committee member mandatory hai.")
  end

  def maker_cannot_be_committee_member
    return unless committee_approval_required?

    maker_employee = user&.employee_master
    return if maker_employee.blank?

    committee_member_ids = committee_steps.reject(&:marked_for_destruction?).map(&:employee_master_id).compact
    return unless committee_member_ids.include?(maker_employee.id)

    if committee_from_policy
      errors.add(:base, "Maker cannot be part of the approval committee.")
      return
    end

    errors.add(:base, "Maker cannot be part of the approval committee.")
  end

  def committee_members_must_be_unique
    return unless committee_approval_required?

    committee_member_ids = committee_steps.reject(&:marked_for_destruction?).map(&:employee_master_id).compact
    return if committee_member_ids.uniq.size == committee_member_ids.size

    errors.add(:base, "Committee members must be unique.")
  end

  def selected_vendors_must_match_stakeholder
    proposal_stakeholder_id = stakeholder_category_id
    return if proposal_stakeholder_id.blank?
    return if vendor_registrations.blank?

    mismatched_vendors = vendor_registrations.reject { |vendor| vendor_matches_stakeholder?(vendor) }
    return if mismatched_vendors.empty?

    vendor_names = mismatched_vendors.map(&:display_name).join(", ")
    errors.add(:base, "Selected vendors must belong to the same stakeholder as the quotation theme. Mismatch: #{vendor_names}")
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
