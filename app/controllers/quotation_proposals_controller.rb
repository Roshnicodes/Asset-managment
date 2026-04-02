class QuotationProposalsController < ApplicationController
  before_action :set_quotation_proposal, only: %i[
    show edit update destroy approve_committee return_committee
    send_to_vendors score_vendor score_vendors select_vendor
  ]
  before_action :authorize_quotation_form_access!, only: %i[index new create edit update destroy send_for_approval send_to_vendors score_vendor score_vendors select_vendor]
  before_action :authorize_quotation_list_access!, only: %i[list]
  before_action :authorize_quotation_view_access!, only: %i[show approve_committee return_committee]
  before_action :authorize_committee_comparison_access!, only: %i[score_vendor select_vendor]

  def index
    @quotation_proposals = own_quotation_scope.order(created_at: :desc)
  end

  def list
    sync_quotation_approval_requests!
    actor_ids = current_approval_employee_ids

    if admin_user?
      @quotation_proposals = quotation_scope.distinct.order(created_at: :desc)
    else
      own_ids = own_quotation_scope.select(:id)
      involved_ids = if actor_ids.any?
        QuotationProposal.joins(approval_request: :approval_steps)
          .where(approval_steps: { employee_master_id: actor_ids })
          .select(:id)
      else
        QuotationProposal.none.select(:id)
      end
      committee_ids = if actor_ids.any?
        QuotationProposal.joins(:committee_steps)
          .where(quotation_proposal_committee_steps: { employee_master_id: actor_ids })
          .select(:id)
      else
        QuotationProposal.none.select(:id)
      end

      @quotation_proposals = quotation_scope.where(id: own_ids)
        .or(quotation_scope.where(id: involved_ids))
        .or(quotation_scope.where(id: committee_ids))
        .distinct
        .order(created_at: :desc)
    end

  end

  def show
    bootstrap_quotation_approval_request_if_needed!(@quotation_proposal)
    @quotation_proposal.approval_request&.ensure_channel_steps_synced!
  end

  def new
    @quotation_proposal = QuotationProposal.new(
      proposal_end_date: Date.current + 7.days,
      workflow_status: "committee_pending"
    )
    @quotation_proposal.quotation_proposal_items.build
    build_committee_steps(@quotation_proposal)
    load_form_collections
  end

  def edit
    @quotation_proposal.quotation_proposal_items.build if @quotation_proposal.quotation_proposal_items.empty?
    build_committee_steps(@quotation_proposal)
    load_form_collections
  end

  def create
    @quotation_proposal = QuotationProposal.new(quotation_proposal_params)
    @quotation_proposal.user = current_user

    if @quotation_proposal.save
      @quotation_proposal.refresh_response_status!
      redirect_to quotation_proposal_path(@quotation_proposal), notice: "Quotation proposal saved successfully."
    else
      build_committee_steps(@quotation_proposal)
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def update
    was_returned = @quotation_proposal.approval_request&.employee_return_pending?

    if @quotation_proposal.update(quotation_proposal_params)
      if was_returned
        @quotation_proposal.rebuild_approval_request_steps!
        NotificationDispatcher.notify_pending_approval_steps(@quotation_proposal.approval_request)
      end

      notice_message = if was_returned
        "Quotation proposal updated and sent back for approval."
      else
        "Quotation proposal updated successfully."
      end

      redirect_to quotation_proposal_path(@quotation_proposal), notice: notice_message, status: :see_other
    else
      build_committee_steps(@quotation_proposal)
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quotation_proposal.destroy!
    redirect_to quotation_proposals_path, notice: "Quotation proposal deleted successfully.", status: :see_other
  end

  def send_for_approval
    proposal_ids = if params[:id].present?
      [params[:id]]
    else
      Array(params[:quotation_proposal_ids]).reject(&:blank?)
    end

    if proposal_ids.blank?
      redirect_to list_quotation_proposals_path, alert: "No quotation proposals were selected."
      return
    end

    sent_count = 0
    failed_count = 0

    QuotationProposal.where(id: proposal_ids).find_each do |quotation_proposal|
      if start_quotation_approval_request!(quotation_proposal)
        sent_count += 1
      else
        failed_count += 1
      end
    end

    redirect_target = params[:id].present? ? quotation_proposal_path(params[:id]) : list_quotation_proposals_path

    if sent_count.positive? && failed_count.zero?
      redirect_to redirect_target, notice: "Quotation proposal approval started successfully."
    elsif sent_count.positive?
      redirect_to redirect_target, alert: "#{sent_count} quotation proposal(s) sent for approval, but #{failed_count} could not be mapped to a valid approval channel."
    else
      redirect_to redirect_target, alert: "No approval request was created. Please check the quotation approval channel mapping."
    end
  end

  def approve_committee
    actor_employee = approval_actor_for(@quotation_proposal)
    approved_step, _next_step = @quotation_proposal.approve_committee_step!(employee: actor_employee, remark: params[:remark].presence)
    if @quotation_proposal.committee_completed?
      NotificationDispatcher.notify_quotation_committee_completed(@quotation_proposal, actor: actor_employee, remark: params[:remark].presence)
    end
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "Committee approval has been saved."
  rescue ActiveRecord::RecordNotFound
    redirect_to quotation_proposal_path(@quotation_proposal), alert: "No pending committee approval was found for your login."
  end

  def return_committee
    remark = params[:remark].to_s.strip
    if remark.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "A remark is required to return this quotation."
      return
    end

    actor_employee = approval_actor_for(@quotation_proposal)
    @quotation_proposal.return_committee_step!(employee: actor_employee, remark: remark)
    NotificationDispatcher.notify_quotation_committee_returned(@quotation_proposal, actor: actor_employee, remark: remark)
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "The quotation has been returned by the committee."
  rescue ActiveRecord::RecordNotFound
    redirect_to quotation_proposal_path(@quotation_proposal), alert: "No pending committee approval was found for your login."
  end

  def send_to_vendors
    unless @quotation_proposal.committee_completed?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "All committee approvals must be completed before sending this quotation to vendors."
      return
    end

    @quotation_proposal.send_to_vendors!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "The quotation request has been sent to the selected vendors."
  rescue QuotationProposal::VendorDispatchError => error
    redirect_to quotation_proposal_path(@quotation_proposal), alert: error.message
  end

  def score_vendor
    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.find(params[:proposal_vendor_id])
    unless proposal_vendor.response_submitted?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Committee score can be added only after the vendor submits a response."
      return
    end

    proposal_vendor.update!(committee_score: params[:committee_score].to_i)
    @quotation_proposal.recalculate_vendor_rankings!
    sync_rank_based_vendor_selection!
    @quotation_proposal.refresh_response_status!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "The vendor comparison score has been updated."
  end

  def score_vendors
    scores_param = params[:committee_scores]
    scores = if scores_param.is_a?(ActionController::Parameters)
      scores_param.permit!.to_h
    else
      scores_param.to_h
    end
    updated = 0

    @quotation_proposal.quotation_proposal_vendors.find_each do |proposal_vendor|
      next unless proposal_vendor.response_submitted?
      next unless scores.key?(proposal_vendor.id.to_s)

      raw_score = scores[proposal_vendor.id.to_s]
      proposal_vendor.update!(committee_score: raw_score.present? ? raw_score.to_i : nil)
      updated += 1
    end

    @quotation_proposal.recalculate_vendor_rankings!
    sync_rank_based_vendor_selection!
    @quotation_proposal.refresh_response_status!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: updated.positive? ? "Committee comparison scores have been updated." : "No committee score changes were submitted."
  end

  def select_vendor
    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.find(params[:proposal_vendor_id])
    unless proposal_vendor.response_submitted?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Only responded vendors can be selected."
      return
    end

    @quotation_proposal.quotation_proposal_vendors.update_all(selected: false)
    proposal_vendor.update!(selected: true)
    @quotation_proposal.update!(selected_vendor_registration: proposal_vendor.vendor_registration)
    @quotation_proposal.refresh_response_status!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "The vendor has been selected successfully."
  end

  private

  def set_quotation_proposal
    @quotation_proposal = QuotationProposal.find(params[:id])
  end

  def quotation_proposal_params
    permitted = params.require(:quotation_proposal).permit(
      :theme_id,
      :subject,
      :proposal_end_date,
      :remark,
      vendor_registration_ids: [],
      quotation_proposal_items_attributes: [:id, :item_name, :unit_id, :quantity, :remark, :_destroy],
      committee_steps_attributes: [:id, :level, :employee_master_id, :remark, :status, :_destroy]
    )

    permitted[:vendor_registration_ids] = Array(permitted[:vendor_registration_ids]).reject(&:blank?)
    permitted
  end

  def quotation_scope
    QuotationProposal.includes(
      :theme,
      :vendor_registrations,
      { committee_steps: :employee_master },
      { quotation_proposal_vendors: [:vendor_registration, { vendor_items: { quotation_proposal_item: :unit } }] },
      approval_request: { approval_steps: :employee_master }
    )
  end

  def own_quotation_scope
    return quotation_scope if admin_user?

    quotation_scope.where(user_id: current_user.id)
  end

  def can_access_menu?(identifier)
    return true if admin_user?

    employee = current_employee_master
    return false unless employee

    role_permissions = MenuPermission.where(
      stakeholder_category_id: employee.stakeholder_category_id,
      designation: employee.designation
    )
    return false if role_permissions.empty?

    if identifier == "quotation_proposal_main"
      return true if role_permissions.find_by(menu_identifier: "quotation_proposal_form")&.can_view?
      return true if role_permissions.find_by(menu_identifier: "quotation_proposal_list")&.can_view?
    end

    role_permissions.find_by(menu_identifier: identifier)&.can_view? || false
  end

  def authorize_quotation_form_access!
    return if can_access_menu?("quotation_proposal_form")

    redirect_to root_path, alert: "You are not authorized to access Quotation Proposal form."
  end

  def authorize_quotation_list_access!
    return if can_access_menu?("quotation_proposal_list") || can_access_menu?("quotation_proposal_form")

    redirect_to root_path, alert: "You are not authorized to view Quotation Proposal list."
  end

  def authorize_quotation_view_access!
    return if @quotation_proposal.committee_user?(current_user)
    return if @quotation_proposal.approval_request&.approval_steps&.any? { |step| employee_matches_current_login?(step.employee_master) }
    return if can_access_menu?("quotation_proposal_form") || can_access_menu?("quotation_proposal_list")

    redirect_to root_path, alert: "You are not authorized to view this Quotation Proposal."
  end

  def load_form_collections
    @themes = Theme.order(:name)
    @units = Unit.order(:name)
    @vendors = VendorRegistration.includes(:themes).order(:vendor_name)
    @committee_members = EmployeeMaster.order(:name)
  end

  def build_committee_steps(quotation_proposal)
    existing_levels = quotation_proposal.committee_steps.map(&:level)

    (1..4).each do |level|
      next if existing_levels.include?(level)

      quotation_proposal.committee_steps.build(level: level, status: "waiting")
    end
  end

  def sync_quotation_approval_requests!
    ApprovalRequest.sync_scope!(
      ApprovalRequest.includes(:approval_channel, :approvable, :approval_steps)
        .where(form_name: ["Quotation Proposal", "Quotation Request"])
    )
  end

  def bootstrap_quotation_approval_request_if_needed!(quotation_proposal)
    return if quotation_proposal.approval_request.present?
    return unless quotation_proposal.committee_steps.where(status: %w[pending approved returned rejected]).exists?

    quotation_proposal.bootstrap_approval_request_from_committee!
  end

  def start_quotation_approval_request!(quotation_proposal)
    return false if quotation_proposal.approval_request.present?

    approval_request = quotation_proposal.bootstrap_approval_request_from_committee!
    return false unless approval_request

    NotificationDispatcher.notify_pending_approval_steps(approval_request)
    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    false
  end

  def authorize_committee_comparison_access!
    return if @quotation_proposal.committee_member?(current_employee_master) || @quotation_proposal.committee_user?(current_user)

    redirect_to quotation_proposal_path(@quotation_proposal), alert: "Only committee members can score vendors and select the final vendor."
  end

  def sync_rank_based_vendor_selection!
    ranked_vendor = @quotation_proposal.quotation_proposal_vendors.find_by(rank_position: 1)

    @quotation_proposal.quotation_proposal_vendors.update_all(selected: false)

    if ranked_vendor.present?
      ranked_vendor.update!(selected: true)
      @quotation_proposal.update!(selected_vendor_registration: ranked_vendor.vendor_registration)
    else
      @quotation_proposal.update!(selected_vendor_registration: nil)
    end
  end
end
