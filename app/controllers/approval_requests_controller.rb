class ApprovalRequestsController < ApplicationController
  before_action :set_approval_request, only: %i[approve reject]
  before_action :ensure_employee_user!

  def index
    @pending_approval_requests = ApprovalRequest.includes(:approvable, :approval_steps)
      .joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_employee_master.id, status: "pending" })
      .order(created_at: :desc)

    @processed_approval_requests = ApprovalRequest.includes(:approvable, :approval_steps)
      .joins(:approval_steps)
      .where(approval_steps: { employee_master_id: current_employee_master.id })
      .where.not(approval_steps: { status: "pending" })
      .order(updated_at: :desc)
  end

  def approve
    @approval_request.approve!(employee: current_employee_master, remark: params[:remark].presence)
    redirect_to approval_requests_path, notice: "Approval moved to next level successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to approval_requests_path, alert: "No pending approval found for your login."
  end

  def reject
    if params[:remark].blank?
      redirect_to approval_requests_path, alert: "Remark is required for rejection."
      return
    end

    @approval_request.reject!(employee: current_employee_master, remark: params[:remark])
    redirect_to approval_requests_path, notice: "Request rejected successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to approval_requests_path, alert: "No pending approval found for your login."
  end

  private

  def set_approval_request
    @approval_request = ApprovalRequest.find(params[:id])
  end

  def ensure_employee_user!
    return if current_employee_master.present?

    redirect_to root_path, alert: "Your login is not mapped to any employee master email."
  end
end
