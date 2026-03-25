class QuotationProposalsController < ApplicationController
  before_action :set_quotation_proposal, only: %i[show edit update destroy send_for_approval]

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
    @quotation_proposal = QuotationProposal.new(proposal_end_date: Date.current + 7.days)
    @quotation_proposal.quotation_proposal_items.build
    load_form_collections
  end

  def edit
    @quotation_proposal.quotation_proposal_items.build if @quotation_proposal.quotation_proposal_items.empty?
    load_form_collections
  end

  def create
    @quotation_proposal = QuotationProposal.new(quotation_proposal_params)
    @quotation_proposal.user = current_user

    if @quotation_proposal.save
      approval_request = create_quotation_approval_request(@quotation_proposal)

      if approval_request.present?
        redirect_to list_quotation_proposals_path, notice: "Quotation proposal created and sent for approval successfully."
      else
        redirect_to quotation_proposals_path, alert: "Quotation proposal was saved as draft. Please configure an Approval Channel for Quotation Proposal, then send it for approval."
      end
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @quotation_proposal.update(quotation_proposal_params)
      redirect_to quotation_proposals_path, notice: "Quotation proposal updated successfully.", status: :see_other
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quotation_proposal.destroy!
    redirect_to quotation_proposals_path, notice: "Quotation proposal deleted successfully.", status: :see_other
  end

  def send_for_approval
    quotation_ids = if params[:id].present?
      [params[:id]]
    else
      Array(params[:quotation_proposal_ids]).reject(&:blank?)
    end

    if quotation_ids.blank?
      redirect_to quotation_proposals_path, alert: "No quotation proposal was selected."
      return
    end

    sent_count = 0
    failed_count = 0

    QuotationProposal.where(id: quotation_ids).each do |quotation_proposal|
      next if quotation_proposal.approval_request.present?

      approval_request = create_quotation_approval_request(quotation_proposal)
      approval_request.present? ? sent_count += 1 : failed_count += 1
    end

    if sent_count.positive? && failed_count.zero?
      redirect_to list_quotation_proposals_path, notice: "Selected quotation proposal(s) sent for approval successfully."
    elsif sent_count.positive?
      redirect_to list_quotation_proposals_path, alert: "#{sent_count} quotation proposal(s) sent, but #{failed_count} could not be mapped to a valid approval channel."
    else
      redirect_to quotation_proposals_path, alert: "No approval request was created. Please configure Approval Channel for Quotation Proposal."
    end
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
      quotation_proposal_items_attributes: [:id, :item_name, :unit_id, :quantity, :remark, :_destroy]
    )

    permitted[:vendor_registration_ids] = Array(permitted[:vendor_registration_ids]).reject(&:blank?)
    permitted
  end

  def quotation_scope
    QuotationProposal.includes(
      :theme,
      :vendor_registrations,
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

  def create_quotation_approval_request(quotation_proposal)
    ApprovalRequestBuilder.create_for!(quotation_proposal, form_name: "Quotation Proposal") ||
      ApprovalRequestBuilder.create_for!(quotation_proposal, form_name: "Quotation Request")
  end

  def load_form_collections
    @themes = Theme.order(:name)
    @units = Unit.order(:name)
    @vendors = VendorRegistration.includes(:themes).order(:vendor_name)
  end
end
