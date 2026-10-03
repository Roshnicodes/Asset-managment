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

  # Where a proposal currently stands and who it is waiting on. Everyone who can
  # see the proposal sees the same answer; `mine` is what turns the badge from a
  # quiet status into a call to action for the person who has to move it.
  QuotationStage = Struct.new(:kind, :label, :actors, :mine, :done, :total, keyword_init: true) do
    def waiting? = actors.any?
    def actor_names = actors.join(", ")
    def progress = total.to_i.positive? ? "#{done}/#{total}" : nil
    def complete? = kind == :selected
  end

  def quotation_stage(quotation_proposal)
    @quotation_stage_cache ||= {}
    @quotation_stage_cache[quotation_proposal.id] ||= build_quotation_stage(quotation_proposal)
  end

  private def build_quotation_stage(proposal)
    employee_ids = current_approval_employee_ids
    approval_request = proposal.approval_request

    if approval_request&.employee_return_pending?
      return QuotationStage.new(
        kind: :returned, label: "Correction by maker",
        actors: [maker_name(proposal)].compact,
        mine: maker?(proposal)
      )
    end

    if approval_request.present? && approval_request.status == "pending"
      steps = approval_request.approval_steps.reject(&:proposal_create_step?)
      waiting = steps.select { |step| step.status == "pending" }
      return QuotationStage.new(
        kind: :approval, label: "Committee approval",
        actors: waiting.filter_map { |step| step.employee_master&.name },
        mine: waiting.any? { |step| employee_ids.include?(step.employee_master_id) },
        done: steps.count { |step| step.status == "approved" }, total: steps.size
      )
    end

    if proposal.selected_vendor_registration_id.present?
      return QuotationStage.new(kind: :selected, label: "Vendor selected", actors: [], mine: false)
    end

    proposal_vendors = proposal.quotation_proposal_vendors.to_a
    responded = proposal_vendors.select { |vendor| vendor.response_status == "responded" }

    # A response is the real signal that the request reached the vendors, so it
    # takes priority over the dispatch timestamp.
    if responded.empty?
      if proposal.sent_to_vendors_at.blank?
        return QuotationStage.new(
          kind: :not_sent, label: approval_request.present? ? "Send to vendors" : "Send for approval",
          actors: [maker_name(proposal)].compact,
          mine: maker?(proposal)
        )
      end

      return QuotationStage.new(
        kind: :vendor_response, label: "Vendor quotation",
        actors: proposal_vendors.filter_map { |vendor| vendor.vendor_registration&.display_name },
        mine: false, done: 0, total: proposal_vendors.size
      )
    end

    if proposal.missing_max_rates?
      return QuotationStage.new(
        kind: :max_rate, label: "Max rate entry",
        actors: [maker_name(proposal)].compact,
        mine: maker?(proposal)
      )
    end

    unless proposal.below_10k?
      members = proposal.committee_steps.filter_map(&:employee_master)
      yet_to_score = members.reject do |member|
        responded.all? do |vendor|
          vendor.committee_member_scores.any? { |score| score.score.present? && score.employee_master_id == member.id }
        end
      end

      if yet_to_score.any?
        return QuotationStage.new(
          kind: :scoring, label: "Committee scoring",
          actors: yet_to_score.map(&:name),
          mine: yet_to_score.any? { |member| employee_ids.include?(member.id) },
          done: members.size - yet_to_score.size, total: members.size
        )
      end
    end

    QuotationStage.new(
      kind: :vendor_selection, label: "Vendor selection",
      actors: proposal.below_10k? ? [maker_name(proposal)].compact : proposal.committee_steps.filter_map { |step| step.employee_master&.name },
      mine: proposal.below_10k? ? maker?(proposal) : proposal.committee_user?(current_user)
    )
  end

  private def maker_name(proposal)
    proposal.user&.employee_master&.name.presence || proposal.user&.email
  end

  private def maker?(proposal)
    current_user.present? && proposal.user_id == current_user.id
  end

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
