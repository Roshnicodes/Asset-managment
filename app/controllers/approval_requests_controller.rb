class ApprovalRequestsController < ApplicationController
  before_action :set_approval_request, only: %i[approve return_request reject]
  before_action :ensure_employee_user!

  def index
    @status = params[:status].presence || default_status
    @form_name = params[:form_name].presence
    is_admin = admin_user?
    actor_ids = current_approval_employee_ids

    sync_visible_approval_requests!

    base_requests = ApprovalRequest.preload(:approvable, approval_steps: :employee_master).order(created_at: :desc)
    base_requests = base_requests.where(form_name: @form_name) if @form_name.present?
    
    unless is_admin
      # Only requests that have actually reached this approver: pending on them
      # now, or already actioned by them. Steps still "waiting" (an earlier
      # level has not acted yet) must not surface the request.
      base_requests = if actor_ids.any?
        base_requests.joins(:approval_steps)
          .where(approval_steps: { employee_master_id: actor_ids, status: ApprovalStep::REACHED_STATUSES })
          .distinct
      else
        ApprovalRequest.none
      end
    end

    actionable_requests = if is_admin
      base_requests.where(status: "pending")
    else
      base_requests.where(status: "pending", approval_steps: { status: "pending" })
    end

    @pending_approval_requests = ApprovalRequest.none
    @processed_approval_requests = ApprovalRequest.none

    case @status
    when "approved", "returned", "rejected"
      @processed_approval_requests = base_requests.where(status: @status)
    when "all"
      @pending_approval_requests = actionable_requests
      @processed_approval_requests = base_requests.where.not(status: "pending")
    else
      @pending_approval_requests = actionable_requests
    end
  end

  def approve
    @approval_request.ensure_channel_steps_synced!
    @approval_request.approve!(employee: approval_actor_for(@approval_request), remark: params[:remark].presence)
    notice_message = if @approval_request.committee_parallel_flow?
      "Committee approval saved successfully."
    else
      "Approval moved to next level successfully."
    end
    redirect_to approval_requests_path(status: "all", form_name: @approval_request.form_name), notice: notice_message
  rescue ActiveRecord::RecordNotFound
    redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "No pending approval found for your login."
  end

  def return_request
    @approval_request.ensure_channel_steps_synced!
    remark = params[:remark].to_s.strip
    return_target = params[:return_target].to_s

    if remark.blank?
      redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "Remark is required for return."
      return
    end

    if return_target == "employee"
      @approval_request.return_to_employee!(employee: approval_actor_for(@approval_request), remark: remark)
      redirect_to approval_requests_path(status: "all", form_name: @approval_request.form_name), notice: "Request returned to employee successfully."
    elsif return_target.start_with?("level:")
      target_level = return_target.delete_prefix("level:").to_i
      @approval_request.return_to_level!(employee: approval_actor_for(@approval_request), target_level: target_level, remark: remark)
      redirect_to approval_requests_path(status: "all", form_name: @approval_request.form_name), notice: "Request returned to #{WorkflowLevelNaming.humanize_level_label(target_level)} successfully."
    elsif return_target == "previous_level"
      @approval_request.return_to_previous_level!(employee: approval_actor_for(@approval_request), remark: remark)
      previous_level = @approval_request.returned_to_level || @approval_request.current_level
      redirect_to approval_requests_path(status: "all", form_name: @approval_request.form_name), notice: "Request returned to #{WorkflowLevelNaming.humanize_level_label(previous_level)} successfully."
    else
      redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "Please select a valid return target."
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "Return target was not available for your login."
  end

  def reject
    @approval_request.ensure_channel_steps_synced!
    if params[:remark].blank?
      redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "Remark is required for rejection."
      return
    end

    @approval_request.reject!(employee: approval_actor_for(@approval_request), remark: params[:remark])
    redirect_to approval_requests_path(status: "all", form_name: @approval_request.form_name), notice: "Request rejected successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to approval_requests_path(status: "pending", form_name: @approval_request.form_name), alert: "No pending approval found for your login."
  end

  private

  def set_approval_request
    @approval_request = ApprovalRequest.find(params[:id])
  end

  def ensure_employee_user!
    return if admin_user?
    return if current_approval_employee_ids.any?

    redirect_to root_path, alert: "Your login is not mapped to any employee master email."
  end

  def default_status
    params[:form_name].present? ? "all" : "pending"
  end

  def sync_visible_approval_requests!
    scope = ApprovalRequest.includes(:approval_channel, :approvable, :approval_steps).active_workflow
    scope = scope.where(form_name: @form_name) if @form_name.present?
    ApprovalRequest.sync_scope!(scope)
  end
end
