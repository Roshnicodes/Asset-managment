class ApprovalRequestsController < ApplicationController
  before_action :set_approval_request, only: %i[approve reject]
  before_action :ensure_employee_user!

  def index
    @status = params[:status].presence || default_status
    @form_name = params[:form_name].presence
    is_admin = current_user.email == "admin@example.com"

    base_requests = ApprovalRequest.preload(:approvable, :approval_steps).order(created_at: :desc)
    base_requests = base_requests.where(form_name: @form_name) if @form_name.present?
    
    unless is_admin
      base_requests = base_requests.joins(:approval_steps).where(approval_steps: { employee_master_id: current_employee_master.id })
    end

    @pending_approval_requests = ApprovalRequest.none
    @processed_approval_requests = ApprovalRequest.none

    case @status
    when "pending"
      @pending_approval_requests = is_admin ? base_requests.where(status: "pending") : base_requests.where(approval_steps: { status: "pending" })
      @processed_approval_requests = ApprovalRequest.none
    when "approved", "rejected"
      @pending_approval_requests = ApprovalRequest.none
      @processed_approval_requests = base_requests.where(status: @status)
    when "all"
      @pending_approval_requests = is_admin ? base_requests.where(status: "pending").distinct : base_requests.where(approval_steps: { status: "pending" }).distinct
      @processed_approval_requests = is_admin ? base_requests.where.not(status: "pending").distinct : base_requests.where.not(approval_steps: { status: "pending" }).distinct
    else
      @pending_approval_requests = is_admin ? base_requests.where(status: "pending") : base_requests.where(approval_steps: { status: "pending" })
      @processed_approval_requests = ApprovalRequest.none
    end
  end

  def approve
    @approval_request.approve!(employee: current_employee_master, remark: params[:remark].presence)
    redirect_to approval_requests_path(status: "all", form_name: @approval_request.form_name), notice: "Approval moved to next level successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "No pending approval found for your login."
  end

  def reject
    if params[:remark].blank?
      redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "Remark is required for rejection."
      return
    end

    @approval_request.reject!(employee: current_employee_master, remark: params[:remark])
    redirect_to approval_requests_path(status: "all", form_name: @approval_request.form_name), notice: "Request rejected successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "No pending approval found for your login."
  end

  private

  def set_approval_request
    @approval_request = ApprovalRequest.find(params[:id])
  end

  def ensure_employee_user!
    return if current_user.email == "admin@example.com"
    return if current_employee_master.present?

    redirect_to root_path, alert: "Your login is not mapped to any employee master email."
  end

  def default_status
    params[:form_name].present? ? "all" : "pending"
  end
end
