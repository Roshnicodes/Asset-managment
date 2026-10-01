# What the signed-in user still has to do on a quotation proposal.
#
# A proposal moves through distinct stages, so at most one kind of work is ever
# waiting on the same person at the same time. Keeping the kinds separate lets
# the sidebar show "Quotation Proposal" and "Committee Scoring" badges that mean
# different things instead of repeating the same number twice.
module QuotationPendingHelper
  QUOTATION_PENDING_LABELS = {
    approval: "Approval pending",
    returned: "Returned to you",
    scoring: "Scoring pending"
  }.freeze

  # => { quotation_proposal_id => :approval | :returned | :scoring }
  def quotation_pending_actions
    return @quotation_pending_actions if defined?(@quotation_pending_actions)

    actions = {}
    actions.merge!(quotation_approval_pending_ids.index_with(:approval))
    actions.merge!(quotation_returned_to_maker_ids.index_with(:returned))
    actions.merge!(pending_committee_scoring_proposals.map(&:id).index_with(:scoring))

    @quotation_pending_actions = actions
  end

  def quotation_pending_kind(quotation_proposal)
    quotation_pending_actions[quotation_proposal.id]
  end

  def quotation_pending_label(quotation_proposal)
    QUOTATION_PENDING_LABELS[quotation_pending_kind(quotation_proposal)]
  end

  # Badge on the "Quotation Proposal" menu: work on the request itself.
  def quotation_approval_pending_count
    quotation_pending_actions.count { |_id, kind| kind != :scoring }
  end

  # Badge on the "Committee Scoring" menu: vendor marks still to be given.
  def quotation_scoring_pending_count
    quotation_pending_actions.count { |_id, kind| kind == :scoring }
  end

  # Quotation proposals where the signed-in committee member still has to score
  # at least one responded vendor.
  def pending_committee_scoring_proposals
    return @pending_committee_scoring_proposals if defined?(@pending_committee_scoring_proposals)

    employee_ids = current_approval_employee_ids
    @pending_committee_scoring_proposals = if employee_ids.blank?
      []
    else
      QuotationProposal
        .joins(:committee_steps)
        .where(quotation_proposal_committee_steps: { employee_master_id: employee_ids })
        .where(selected_vendor_registration_id: nil)
        .includes(:quotation_proposal_items, quotation_proposal_vendors: :committee_member_scores)
        .distinct
        .select { |quotation_proposal| committee_scoring_pending_for?(quotation_proposal, employee_ids) }
    end
  end

  def pending_committee_scoring_count
    pending_committee_scoring_proposals.size
  end

  private

  def quotation_approval_pending_ids
    employee_ids = current_approval_employee_ids
    return [] if employee_ids.blank?

    ApprovalRequest
      .where(approvable_type: "QuotationProposal", status: "pending")
      .joins(:approval_steps)
      .where(approval_steps: { employee_master_id: employee_ids, status: "pending" })
      .distinct
      .pluck(:approvable_id)
  end

  def quotation_returned_to_maker_ids
    return [] if current_user.blank?

    QuotationProposal
      .where(user_id: current_user.id)
      .joins(:approval_request)
      .where(approval_requests: { status: "returned", return_mode: "employee" })
      .pluck(:id)
  end

  def committee_scoring_pending_for?(quotation_proposal, employee_ids)
    return false if quotation_proposal.below_10k?
    return false unless quotation_proposal.all_max_rates_present?

    responded_vendors = quotation_proposal.quotation_proposal_vendors.select { |vendor| vendor.response_status == "responded" }
    return false if responded_vendors.empty?

    responded_vendors.any? do |vendor|
      vendor.committee_member_scores.none? do |score|
        score.score.present? && employee_ids.include?(score.employee_master_id)
      end
    end
  end
end
