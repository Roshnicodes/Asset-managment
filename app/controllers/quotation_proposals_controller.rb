class QuotationProposalsController < ApplicationController
  before_action :set_quotation_proposal, only: %i[
    show edit update destroy send_for_approval approve_committee return_committee
    send_to_vendors score_vendor select_vendor
  ]
  before_action :authorize_quotation_form_access!, only: %i[index new create edit update destroy send_for_approval send_to_vendors score_vendor select_vendor]
  before_action :authorize_quotation_list_access!, only: %i[list]
  before_action :authorize_quotation_view_access!, only: %i[show approve_committee return_committee]

  def index
    @quotation_proposals = own_quotation_scope.order(created_at: :desc)
  end

  def list
    if admin_user?
      @quotation_proposals = quotation_scope.joins(:approval_request).distinct.order(created_at: :desc)
    else
      own_ids = own_quotation_scope.joins(:approval_request).select(:id)
      involved_ids = if current_employee_master.present?
        QuotationProposal.joins(approval_request: :approval_steps)
          .where(approval_steps: { employee_master_id: current_employee_master.id })
          .select(:id)
      else
        QuotationProposal.none.select(:id)
      end

      @quotation_proposals = quotation_scope.where(id: own_ids)
        .or(quotation_scope.where(id: involved_ids))
        .distinct
        .order(created_at: :desc)
    end
  end

  def show
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
      @quotation_proposal.normalize_committee_steps!
      NotificationDispatcher.notify_all_quotation_committee_steps(@quotation_proposal)
      redirect_to quotation_proposal_path(@quotation_proposal), notice: "Quotation proposal and approval committee saved successfully."
    else
      build_committee_steps(@quotation_proposal)
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @quotation_proposal.update(quotation_proposal_params)
      redirect_to quotation_proposal_path(@quotation_proposal), notice: "Quotation proposal updated successfully.", status: :see_other
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
    @quotation_proposal.normalize_committee_steps!
    NotificationDispatcher.notify_all_quotation_committee_steps(@quotation_proposal)
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "Committee approval has been activated and notifications have been sent to all committee members."
  end

  def approve_committee
    approved_step, _next_step = @quotation_proposal.approve_committee_step!(employee: current_employee_master, remark: params[:remark].presence)
    if @quotation_proposal.committee_completed?
      NotificationDispatcher.notify_quotation_committee_completed(@quotation_proposal, actor: current_employee_master, remark: params[:remark].presence)
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

    @quotation_proposal.return_committee_step!(employee: current_employee_master, remark: remark)
    NotificationDispatcher.notify_quotation_committee_returned(@quotation_proposal, actor: current_employee_master, remark: remark)
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
  end

  def score_vendor
    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.find(params[:proposal_vendor_id])
    proposal_vendor.update!(committee_score: params[:committee_score].to_i)
    @quotation_proposal.recalculate_vendor_rankings!
    @quotation_proposal.refresh_response_status!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "The vendor comparison score has been updated."
  end

  def select_vendor
    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.find(params[:proposal_vendor_id])
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
      approval_request: :approval_steps
    )
  end

  def own_quotation_scope
    return quotation_scope if admin_user?

    quotation_scope.where(user_id: current_user.id)
  end

  def admin_user?
    current_user.email == "admin@example.com" || current_user.employee_master&.user_type == "Admin"
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
    return if can_access_menu?("quotation_proposal_form") || can_access_menu?("quotation_proposal_list")

    redirect_to root_path, alert: "You are not authorized to view this Quotation Proposal."
  end

  def create_quotation_approval_request(quotation_proposal)
    ApprovalRequestBuilder.create_for!(quotation_proposal, form_name: "Quotation Proposal") ||
      ApprovalRequestBuilder.create_for!(quotation_proposal, form_name: "Quotation Request")
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

      quotation_proposal.committee_steps.build(level: level, status: "pending")
    end
  end
end
