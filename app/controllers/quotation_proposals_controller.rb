class QuotationProposalsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :handle_quotation_not_found

  before_action :set_quotation_proposal, only: %i[
    show edit update destroy approve_committee return_committee
    send_to_vendors score_vendor score_vendors select_vendor purchase_order send_purchase_order update_purchase_order_reply goods_receive update_goods_receive
    new_invoice_request_assets create_invoice_request_assets review_invoice_request assign_payment_references
  ]
  before_action :ensure_quotation_owner_access!, only: %i[edit update destroy send_to_vendors purchase_order send_purchase_order goods_receive update_goods_receive new_invoice_request_assets create_invoice_request_assets review_invoice_request]
  before_action :ensure_quotation_owner_access!, only: %i[assign_payment_references]
  before_action :ensure_quotation_change_allowed!, only: %i[edit update destroy]
  before_action :authorize_quotation_form_access!, only: %i[index new create edit update destroy send_for_approval send_to_vendors]
  before_action :authorize_quotation_list_access!, only: %i[list]
  before_action :authorize_payment_advice_access!, only: %i[payment_advice update_payment_advice]
  before_action :authorize_quotation_view_access!, only: %i[show approve_committee return_committee]
  before_action :authorize_committee_comparison_access!, only: %i[score_vendor score_vendors select_vendor]

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

  def payment_advice
    @payment_advice_requests = QuotationProposalVendorInvoiceRequest
      .includes(
        :payment_reference_marked_by,
        :payment_advice_updated_by,
        { vendor_invoices_attachments: :blob },
        quotation_proposal_vendor: [:vendor_registration, :quotation_proposal]
      )
      .where.not(pdo_no: [nil, ""])
      .where.not(rfp_no: [nil, ""])
      .where.not(rfp_created_on: nil)
      .where(payment_advice_sent_at: nil)
      .order(payment_reference_marked_at: :desc, updated_at: :desc)
  end

  def show
    @quotation_proposal.approval_request&.ensure_channel_steps_synced!
    if @quotation_proposal.vendor_responses_received? && @quotation_proposal.all_max_rates_present?
      @quotation_proposal.sync_vendor_rankings_and_selection!
      @quotation_proposal.reload
    end
    @current_scoring_employee = approval_actor_for(@quotation_proposal)
    @committee_scoring_allowed = committee_scoring_allowed_for?(@quotation_proposal)
    @committee_member_count = @quotation_proposal.committee_steps.size
    @selected_vendor_response = QuotationProposalVendor
      .includes(
        :vendor_registration,
        :purchase_order_authorized_by,
        :purchase_order_reply_updated_by,
        purchase_order_activities: :employee_master,
        invoice_requests: [:maker_reviewed_by, :payment_reference_marked_by, :payment_advice_updated_by, { assets: :product }, { vendor_invoices_attachments: :blob }]
      )
      .find_by(
        quotation_proposal_id: @quotation_proposal.id,
        vendor_registration_id: @quotation_proposal.selected_vendor_registration_id
      )
  end

  def new
    @quotation_proposal = QuotationProposal.new(
      proposal_end_date: Date.current + 7.days,
      workflow_status: "committee_pending",
      procurement_amount_bucket: "above_10k"
    )
    @quotation_proposal.quotation_proposal_items.build
    build_committee_steps(@quotation_proposal)
    @selected_vendor_selection_criterion_ids = @quotation_proposal.selected_vendor_selection_criterion_ids
    load_form_collections
  end

  def edit
    @quotation_proposal.quotation_proposal_items.build if @quotation_proposal.quotation_proposal_items.empty?
    build_committee_steps(@quotation_proposal)
    @selected_vendor_selection_criterion_ids = @quotation_proposal.selected_vendor_selection_criterion_ids
    load_form_collections
  end

  def create
    attrs = quotation_proposal_params.to_h.deep_dup
    item_attributes = raw_quotation_item_attributes
    selected_criteria_ids = extract_vendor_selection_criterion_ids!(attrs)
    attrs.delete("quotation_proposal_items_attributes")
    attrs.delete(:quotation_proposal_items_attributes)

    @quotation_proposal = QuotationProposal.new(attrs)
    @quotation_proposal.user = current_user
    build_quotation_items(@quotation_proposal, item_attributes)
    @selected_vendor_selection_criterion_ids = selected_criteria_ids

    if persist_quotation_proposal_with_criteria(@quotation_proposal, selected_criteria_ids)
      @quotation_proposal.refresh_response_status!
      redirect_to quotation_proposal_path(@quotation_proposal), notice: "Quotation proposal saved successfully."
    else
      build_committee_steps(@quotation_proposal)
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attrs = quotation_proposal_params.to_h.deep_dup
    item_attributes = raw_quotation_item_attributes
    selected_criteria_ids = extract_vendor_selection_criterion_ids!(attrs)
    attrs.delete("quotation_proposal_items_attributes")
    attrs.delete(:quotation_proposal_items_attributes)
    was_returned = @quotation_proposal.approval_request&.employee_return_pending?
    @selected_vendor_selection_criterion_ids = selected_criteria_ids

    updated = update_quotation_proposal_with_criteria(@quotation_proposal, attrs, item_attributes, selected_criteria_ids)

    if updated
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
      next unless quotation_proposal.user_id == current_user.id

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

    if @quotation_proposal.below_10k?
      proposal_vendor = @quotation_proposal.quotation_proposal_vendors.order(:id).first
      if proposal_vendor.present?
        redirect_to quotation_vendor_qr_path(proposal_vendor.qr_token, verified: 1, direct_access: 1), notice: "Direct quotation form is ready. Please fill the response details."
      else
        redirect_to quotation_proposal_path(@quotation_proposal), alert: "No vendor is available for direct response."
      end
    else
      redirect_to quotation_proposal_path(@quotation_proposal), notice: "The quotation request has been sent to the selected vendors."
    end
  rescue QuotationProposal::VendorDispatchError => error
    redirect_to quotation_proposal_path(@quotation_proposal), alert: error.message
  end

  def purchase_order
    load_purchase_order_context!
  end

  def goods_receive
    load_goods_receive_context!
  end

  def send_purchase_order
    load_purchase_order_context!
    return if performed?
    was_sent_before = @selected_proposal_vendor.purchase_order_sent_at.present?
    due_date = parse_purchase_order_due_date
    locked_authorized_by = @selected_proposal_vendor.purchase_order_authorized_by if was_sent_before

    if @selected_proposal_vendor.vendor_registration.mobile_no.blank?
      redirect_to purchase_order_quotation_proposal_path(@quotation_proposal, authorized_by_id: @authorized_by&.id), alert: "Selected vendor does not have a registered mobile number."
      return
    end

    if due_date.blank?
      redirect_to purchase_order_quotation_proposal_path(@quotation_proposal, authorized_by_id: @authorized_by&.id), alert: "Please add the purchase order last date before sending."
      return
    end

    @selected_proposal_vendor.ensure_po_token!
    dispatch = @selected_proposal_vendor.dispatch_record!
    sent = QuotationVendorSmsGateway.send_purchase_order_link(dispatch, @selected_proposal_vendor)

    unless sent
      redirect_to purchase_order_quotation_proposal_path(@quotation_proposal, authorized_by_id: @authorized_by&.id), alert: sms_delivery_failure_alert("Purchase order SMS could not be delivered. Please verify the SMS setup and try again.")
      return
    end

    @selected_proposal_vendor.update!(
      purchase_order_authorized_by: locked_authorized_by || @authorized_by,
      purchase_order_status: "sent",
      purchase_order_due_date: due_date,
      purchase_order_sent_at: Time.current,
      purchase_order_actioned_at: nil,
      purchase_order_remark: nil
    )
    @selected_proposal_vendor.add_purchase_order_activity!(
      action_type: was_sent_before ? "resent_to_vendor" : "sent_to_vendor",
      actor_name: actor_display_name,
      actor_role: actor_role_label,
      note: "Purchase order sent to vendor mobile number #{@selected_proposal_vendor.vendor_registration.mobile_no}. Last response date: #{due_date.strftime("%d-%m-%Y")}.",
      employee_master: approval_actor_for(@quotation_proposal),
      user: current_user,
      occurred_at: Time.current
    )
    NotificationDispatcher.notify_purchase_order_sent(@quotation_proposal, @selected_proposal_vendor)
    redirect_to purchase_order_quotation_proposal_path(@quotation_proposal, authorized_by_id: @authorized_by&.id), notice: "Purchase order link has been sent to the selected vendor."
  end

  def update_purchase_order_reply
    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.find(params[:proposal_vendor_id])
    unless current_user == @quotation_proposal.user || @quotation_proposal.committee_user?(current_user)
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Only maker or committee members can update the purchase order reply."
      return
    end

    reply_text = params[:purchase_order_reply].to_s.strip
    if reply_text.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Reply cannot be blank."
      return
    end

    actor_employee = approval_actor_for(@quotation_proposal)
    proposal_vendor.update!(
      purchase_order_reply: reply_text,
      purchase_order_reply_updated_at: Time.current,
      purchase_order_reply_updated_by: actor_employee
    )
    proposal_vendor.add_purchase_order_activity!(
      action_type: "reply_updated",
      actor_name: actor_display_name,
      actor_role: actor_role_label,
      note: reply_text,
      employee_master: actor_employee,
      user: current_user,
      occurred_at: Time.current
    )

    NotificationDispatcher.notify_purchase_order_reply_updated(@quotation_proposal, proposal_vendor, actor_name: actor_display_name)
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "Purchase order reply has been updated."
  end

  def update_goods_receive
    load_goods_receive_context!
    return if performed?

    item_params = params.fetch(:goods_receive_items, {}).permit!.to_h
    received_batch_items = []

    QuotationProposalVendorItem.transaction do
      @goods_receive_vendor.vendor_items.each do |vendor_item|
        raw_item_params = item_params[vendor_item.id.to_s] || {}
        goods_received_value = parse_boolean_param(raw_item_params["goods_received"])
        fixed_asset_value = parse_boolean_param(raw_item_params["fixed_asset"])
        receive_now_quantity = raw_item_params["receive_now_quantity"].to_d

        if goods_received_value == true
          if receive_now_quantity <= 0
            raise ActiveRecord::RecordInvalid.new(vendor_item), "Receive now quantity must be greater than zero when goods receive is Yes."
          end

          if receive_now_quantity > vendor_item.pending_quantity
            raise ActiveRecord::RecordInvalid.new(vendor_item), "Receive now quantity cannot be greater than pending quantity."
          end
        else
          receive_now_quantity = 0.to_d
        end

        if receive_now_quantity.positive?
          received_batch_items << build_received_batch_item(vendor_item, receive_now_quantity)
        end

        updated_received_quantity = vendor_item.received_quantity.to_d + receive_now_quantity
        completed_receive = updated_received_quantity >= vendor_item.quantity.to_d

        vendor_item.update!(
          received_quantity: updated_received_quantity,
          goods_received: completed_receive,
          fixed_asset: updated_received_quantity.positive? ? fixed_asset_value : nil,
          last_goods_received_at: receive_now_quantity.positive? ? Time.current : vendor_item.last_goods_received_at
        )
      end
    end

    invoice_request = nil
    invoice_request_notice = nil
    if received_batch_items.any?
      invoice_request = @goods_receive_vendor.invoice_requests.create!(
        item_snapshot: received_batch_items,
        requested_at: Time.current,
        status: "pending_invoice"
      )
      invoice_request.ensure_request_token!

      @goods_receive_vendor.add_purchase_order_activity!(
        action_type: "goods_receive_invoice_requested",
        actor_name: actor_display_name,
        actor_role: actor_role_label,
        note: goods_receive_invoice_note_for(received_batch_items),
        employee_master: approval_actor_for(@quotation_proposal),
        user: current_user,
        occurred_at: invoice_request.requested_at
      )

      dispatch = @goods_receive_vendor.dispatch_record!
      sms_sent = QuotationVendorSmsGateway.send_goods_receive_invoice_link(dispatch, invoice_request)
      if sms_sent
        NotificationDispatcher.notify_goods_receive_invoice_requested(@quotation_proposal, @goods_receive_vendor, invoice_request)
        invoice_request_notice = " Invoice upload link has been sent to the vendor mobile number."
      else
        invoice_request_notice = " Goods receive saved, but #{sms_delivery_failure_alert("invoice upload SMS could not be delivered.")}"
      end
    end

    refreshed_items = @goods_receive_vendor.vendor_items.includes(:quotation_proposal_item).sort_by(&:quotation_proposal_item_id)
    payload = {
      notice: "Goods receive details have been submitted successfully.#{invoice_request_notice}",
      items: refreshed_items.map do |vendor_item|
        {
          id: vendor_item.id,
          ordered_quantity: vendor_item.quantity.to_s,
          received_quantity: vendor_item.received_quantity.to_s,
          pending_quantity: vendor_item.pending_quantity.to_s,
          goods_received: vendor_item.goods_received,
          fixed_asset: vendor_item.fixed_asset,
          fully_received: vendor_item.fully_received?,
          partially_received: vendor_item.partially_received?,
          last_goods_received_at: vendor_item.last_goods_received_at&.strftime("%d-%m-%Y %H:%M")
        }
      end,
      invoice_request: invoice_request.present? ? {
        id: invoice_request.id,
        status: invoice_request.status.to_s.humanize,
        requested_at: invoice_request.requested_at&.strftime("%d-%m-%Y %H:%M"),
        items_label: received_batch_items.map { |item| "#{item[:item_name]} (#{item[:received_quantity]})" }.join(", ")
      } : nil
    }

    respond_to do |format|
      format.html { redirect_to goods_receive_quotation_proposal_path(@quotation_proposal), notice: payload[:notice] }
      format.json { render json: payload }
    end
  rescue ActiveRecord::RecordInvalid => error
    respond_to do |format|
      format.html { redirect_to goods_receive_quotation_proposal_path(@quotation_proposal), alert: error.message }
      format.json { render json: { error: error.message }, status: :unprocessable_entity }
    end
  end

  def new_invoice_request_assets
    redirect_to assets_path(invoice_request_id: params[:invoice_request_id], anchor: "asset-workspace")
  end

  def review_invoice_request
    @invoice_request = QuotationProposalVendorInvoiceRequest
      .includes(:maker_reviewed_by, quotation_proposal_vendor: :vendor_registration)
      .find_by(
        id: params[:invoice_request_id],
        quotation_proposal_vendor_id: @quotation_proposal.quotation_proposal_vendors.select(:id)
      )

    if @invoice_request.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Invoice request was not found."
      return
    end

    unless current_user == @quotation_proposal.user
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Only maker can accept or return the vendor invoice."
      return
    end

    unless @invoice_request.uploaded?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Only uploaded invoices can be reviewed."
      return
    end

    review_action = params[:invoice_review_action].to_s
    review_remark = params[:maker_review_remark].to_s.strip
    review_time = Time.current

    case review_action
    when "accept"
      @invoice_request.update!(
        status: "accepted",
        maker_review_remark: review_remark.presence,
        maker_reviewed_at: review_time,
        maker_reviewed_by: current_employee_master,
        accepted_at: review_time,
        returned_at: nil
      )

      @invoice_request.quotation_proposal_vendor.add_purchase_order_activity!(
        action_type: "goods_receive_invoice_accepted",
        actor_name: actor_display_name,
        actor_role: "Maker",
        employee_master: current_employee_master,
        user: current_user,
        note: review_remark.presence || "Vendor invoice accepted by maker.",
        occurred_at: review_time
      )

      NotificationDispatcher.notify_goods_receive_invoice_accepted(@quotation_proposal, @invoice_request.quotation_proposal_vendor, @invoice_request)
      redirect_to quotation_proposal_path(@quotation_proposal), notice: "Vendor invoice accepted successfully."
    when "return"
      if review_remark.blank?
        redirect_to quotation_proposal_path(@quotation_proposal), alert: "Return remark is required before sending invoice back to vendor."
        return
      end

      @invoice_request.update!(
        status: "returned",
        maker_review_remark: review_remark,
        maker_reviewed_at: review_time,
        maker_reviewed_by: current_employee_master,
        returned_at: review_time,
        accepted_at: nil,
        assets_created_at: nil
      )

      @invoice_request.quotation_proposal_vendor.add_purchase_order_activity!(
        action_type: "goods_receive_invoice_returned",
        actor_name: actor_display_name,
        actor_role: "Maker",
        employee_master: current_employee_master,
        user: current_user,
        note: review_remark,
        occurred_at: review_time
      )

      dispatch = @invoice_request.quotation_proposal_vendor.dispatch_record!
      sms_sent = QuotationVendorSmsGateway.send_goods_receive_invoice_return_link(dispatch, @invoice_request)
      NotificationDispatcher.notify_goods_receive_invoice_returned(@quotation_proposal, @invoice_request.quotation_proposal_vendor, @invoice_request)

      redirect_to quotation_proposal_path(@quotation_proposal), notice: "Vendor invoice returned successfully.#{sms_sent ? " Re-upload link has been sent to vendor." : " #{sms_delivery_failure_alert("SMS could not be delivered to vendor.")}"}"
    else
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Please choose a valid invoice review action."
    end
  end

  def assign_payment_references
    invoice_request_ids = Array(params[:invoice_request_ids]).reject(&:blank?).map(&:to_i)
    pdo_no = params[:pdo_no].to_s.strip
    rfp_no = params[:rfp_no].to_s.strip
    rfp_created_on = parse_finance_date(params[:rfp_created_on])

    if invoice_request_ids.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Please select at least one accepted invoice request."
      return
    end

    if pdo_no.blank? || rfp_no.blank? || rfp_created_on.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "PDO No, RFP No, and RFP Create Date are required."
      return
    end

    selected_requests = QuotationProposalVendorInvoiceRequest
      .includes(quotation_proposal_vendor: :vendor_registration)
      .where(id: invoice_request_ids, quotation_proposal_vendor_id: @quotation_proposal.quotation_proposal_vendors.select(:id))

    eligible_requests = selected_requests.select { |request| request.accepted? && !request.payment_reference_assigned? }

    if eligible_requests.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "No eligible accepted invoice request was selected for finance processing."
      return
    end

    marked_at = Time.current
    actor_employee = approval_actor_for(@quotation_proposal)

    QuotationProposalVendorInvoiceRequest.transaction do
      eligible_requests.each do |request|
        request.update!(
          pdo_no: pdo_no,
          rfp_no: rfp_no,
          rfp_created_on: rfp_created_on,
          payment_reference_marked_at: marked_at,
          payment_reference_marked_by: actor_employee
        )

        request.quotation_proposal_vendor.add_purchase_order_activity!(
          action_type: "invoice_sent_to_finance",
          actor_name: actor_display_name,
          actor_role: actor_role_label,
          note: "Invoice request #{request.id} marked for finance processing. PDO No: #{pdo_no}, RFP No: #{rfp_no}, RFP Create Date: #{rfp_created_on.strftime("%d-%m-%Y")}.",
          employee_master: actor_employee,
          user: current_user,
          occurred_at: marked_at
        )
      end
    end

    redirect_to quotation_proposal_path(@quotation_proposal), notice: "#{eligible_requests.size} invoice request(s) moved to finance queue successfully."
  end

  def update_payment_advice
    invoice_request_ids = Array(params[:invoice_request_ids]).reject(&:blank?).map(&:to_i).uniq

    if invoice_request_ids.blank?
      redirect_to payment_advice_quotation_proposals_path, alert: "Please select at least one finance-queued invoice request."
      return
    end

    unless finance_transaction_columns_available?
      redirect_to payment_advice_quotation_proposals_path, alert: "Finance transaction fields are not available yet. Please run db:migrate first."
      return
    end

    transaction_type = params[:transaction_type].to_s.strip
    transaction_no = params[:transaction_no].to_s.strip
    transaction_date = parse_finance_date(params[:transaction_date])

    if transaction_type.blank? || transaction_no.blank? || transaction_date.blank?
      redirect_to payment_advice_quotation_proposals_path, alert: "Transaction type, transaction number, and transaction date are required."
      return
    end

    unless QuotationProposalVendorInvoiceRequest::TRANSACTION_TYPES.include?(transaction_type)
      redirect_to payment_advice_quotation_proposals_path, alert: "Please choose a valid transaction type."
      return
    end

    selected_requests = QuotationProposalVendorInvoiceRequest
      .includes(quotation_proposal_vendor: [:vendor_registration, :quotation_proposal])
      .where(id: invoice_request_ids)

    eligible_requests = selected_requests.select(&:payment_advice_pending?)

    if eligible_requests.blank?
      redirect_to payment_advice_quotation_proposals_path, alert: "No eligible finance-queued invoice request was selected."
      return
    end

    advice_time = Time.current
    actor_employee = current_employee_master

    QuotationProposalVendorInvoiceRequest.transaction do
      eligible_requests.each do |invoice_request|
        invoice_request.update!(
          transaction_type: transaction_type,
          transaction_no: transaction_no,
          transaction_date: transaction_date,
          payment_advice_sent_at: advice_time,
          payment_advice_updated_by: actor_employee
        )

        proposal_vendor = invoice_request.quotation_proposal_vendor
        quotation_proposal = proposal_vendor.quotation_proposal

        proposal_vendor.add_purchase_order_activity!(
          action_type: "payment_advice_sent",
          actor_name: actor_display_name,
          actor_role: "Finance",
          note: "Finance payment details recorded for invoice request #{invoice_request.id}. Transaction Type: #{transaction_type}, Transaction No: #{transaction_no}, Transaction Date: #{transaction_date.strftime("%d-%m-%Y")}.",
          employee_master: actor_employee,
          user: current_user,
          occurred_at: advice_time
        )

        NotificationDispatcher.notify_invoice_payment_advice_sent(quotation_proposal, proposal_vendor, invoice_request, actor_name: actor_display_name)
      end
    end

    skipped_count = invoice_request_ids.size - eligible_requests.size
    notice = "#{eligible_requests.size} invoice request(s) updated successfully. Vendor notification API is pending integration."
    notice = "#{notice} #{skipped_count} selected record(s) were skipped because they were no longer pending." if skipped_count.positive?

    redirect_to payment_advice_quotation_proposals_path, notice: notice
  end

  def create_invoice_request_assets
    Asset.ensure_structured_code_columns_loaded!
    load_invoice_request_asset_context!
    return if performed?

    @asset_products = Product.includes(:product_varieties).order(:name)
    @asset_rows = asset_row_params
    created_assets = []

    if @asset_rows.blank?
      redirect_to assets_path(invoice_request_id: @invoice_request.id, anchor: "asset-workspace"), alert: "No asset rows were submitted."
      return
    end

    Asset.transaction do
      @asset_rows.each do |row|
        product_id = row[:product_id].presence
        stakeholder_category_id = row[:stakeholder_category_id].presence
        primary_office_category_id = row[:primary_office_category_id].presence
        secondary_office_category_id = row[:secondary_office_category_id].presence
        asset_code_date = row[:asset_code_date].presence

        if product_id.blank?
          raise ActiveRecord::RecordInvalid.new(Asset.new), "Please select a product for every asset row."
        end

        if stakeholder_category_id.blank?
          raise ActiveRecord::RecordInvalid.new(Asset.new), "Please select a stakeholder for every asset row."
        end

        if primary_office_category_id.blank?
          raise ActiveRecord::RecordInvalid.new(Asset.new), "Please select the first location for every asset row."
        end

        if secondary_office_category_id.blank?
          raise ActiveRecord::RecordInvalid.new(Asset.new), "Please select the second location for every asset row."
        end

        if asset_code_date.blank?
          raise ActiveRecord::RecordInvalid.new(Asset.new), "Please add the asset code date for every asset row."
        end

        product = Product.find(product_id)
        unique_product_code = row[:unique_product_code].to_s.strip.presence || product.product_code.to_s.strip.presence

        if unique_product_code.blank?
          raise ActiveRecord::RecordInvalid.new(Asset.new), "Product code is required for every asset row. Please add it in Product Entry or update the item no."
        end

        vendor_item = @invoice_request.quotation_proposal_vendor.vendor_items.find(row[:vendor_item_id])
        stakeholder = StakeholderCategory.find(stakeholder_category_id)
        primary_office = OfficeCategory.find(primary_office_category_id)
        secondary_office = OfficeCategory.find(secondary_office_category_id)

        created_assets << Asset.create!(
          name: row[:asset_name].presence || vendor_item.item_name,
          product: product,
          unique_product_code: unique_product_code,
          stakeholder_category: stakeholder,
          primary_office_category: primary_office,
          secondary_office_category: secondary_office,
          asset_code_date: asset_code_date,
          quotation_proposal_vendor_invoice_request: @invoice_request,
          quotation_proposal_vendor_item: vendor_item
        )
      end

      @invoice_request.update!(assets_created_at: Time.current)
    end

    @invoice_request.quotation_proposal_vendor.add_purchase_order_activity!(
      action_type: "assets_created",
      actor_name: actor_display_name,
      actor_role: actor_role_label,
      note: "Assets created for invoice request #{@invoice_request.id} on #{@invoice_request.assets_created_at&.strftime("%d-%m-%Y %H:%M") || Time.current.strftime("%d-%m-%Y %H:%M")}.",
      employee_master: approval_actor_for(@quotation_proposal),
      user: current_user,
      occurred_at: @invoice_request.assets_created_at || Time.current
    )

    redirect_to asset_insurances_path(asset_ids: created_assets.map(&:id).join(",")),
                notice: "Assets have been created successfully. Please update insurance details below."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to assets_path(invoice_request_id: @invoice_request.id, anchor: "asset-workspace"), alert: error.message
  end

  def score_vendor
    actor_employee = approval_actor_for(@quotation_proposal)
    unless actor_employee.present?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Committee member login required to save vendor score."
      return
    end

    if @quotation_proposal.criteria_based_scoring?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Please use the committee comparison matrix to save criteria-based marks."
      return
    end

    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.find(params[:proposal_vendor_id])
    unless proposal_vendor.response_submitted?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Committee score can be added only after the vendor submits a response."
      return
    end

    score_record = proposal_vendor.committee_member_scores.find_or_initialize_by(employee_master: actor_employee)
    raw_score = params[:committee_score]
    score_record.update!(
      score: raw_score.present? ? raw_score.to_i : nil,
      remark: params[:committee_remark].to_s.strip.presence
    )
    @quotation_proposal.sync_vendor_rankings_and_selection!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "Your committee score has been updated."
  end

  def score_vendors
    actor_employee = approval_actor_for(@quotation_proposal)
    unless actor_employee.present?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Committee member login required to save vendor scores."
      return
    end

    if @quotation_proposal.criteria_based_scoring?
      updated = sync_committee_criteria_scores(actor_employee)
      @quotation_proposal.sync_vendor_rankings_and_selection!
      redirect_to quotation_proposal_path(@quotation_proposal), notice: updated.positive? ? "Your committee criteria marks have been updated." : "Your committee criteria marks have been saved."
      return
    end

    scores_param = params[:committee_scores]
    remarks = raw_committee_remarks
    scores = if scores_param.is_a?(ActionController::Parameters)
      scores_param.permit!.to_h
    elsif scores_param.respond_to?(:to_h)
      scores_param.to_h
    else
      {}
    end
    updated = 0

    @quotation_proposal.quotation_proposal_vendors.find_each do |proposal_vendor|
      next unless proposal_vendor.response_submitted?
      next unless scores.key?(proposal_vendor.id.to_s)

      raw_score = scores[proposal_vendor.id.to_s]
      score_record = proposal_vendor.committee_member_scores.find_or_initialize_by(employee_master: actor_employee)
      score_record.update!(
        score: raw_score.present? ? raw_score.to_i : nil,
        remark: remarks[proposal_vendor.id.to_s].to_s.strip.presence
      )
      updated += 1
    end

    @quotation_proposal.sync_vendor_rankings_and_selection!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: updated.positive? ? "Your committee comparison scores have been updated." : "No committee score changes were submitted."
  end

  def select_vendor
    proposal_vendor = @quotation_proposal.quotation_proposal_vendors.find(params[:proposal_vendor_id])
    unless proposal_vendor.response_submitted?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Only responded vendors can be selected."
      return
    end
    unless @quotation_proposal.vendor_matches_stakeholder?(proposal_vendor.vendor_registration)
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "This vendor does not belong to the same stakeholder as the quotation theme."
      return
    end

    @quotation_proposal.quotation_proposal_vendors.update_all(selected: false)
    proposal_vendor.update_column(:selected, true)
    @quotation_proposal.sync_selected_vendor_registration!(proposal_vendor.vendor_registration)
    @quotation_proposal.refresh_response_status!
    redirect_to quotation_proposal_path(@quotation_proposal), notice: "The vendor has been selected successfully."
  end

  private

  def set_quotation_proposal
    @quotation_proposal = QuotationProposal.includes(theme: :stakeholder_category, criteria_selections: :vendor_selection_criterion).find(params[:id])
  end

  def handle_quotation_not_found
    redirect_to quotation_proposals_path, alert: "The requested quotation proposal could not be found."
  end

  def quotation_proposal_params
    permitted = params.require(:quotation_proposal).permit(
      :theme_id,
      :subject,
      :proposal_end_date,
      :remark,
      :procurement_amount_bucket,
      vendor_registration_ids: [],
      vendor_selection_criterion_ids: [],
      quotation_proposal_items_attributes: [:id, :item_name, :unit_id, :quantity, :max_rate, :remark, :_destroy],
      committee_steps_attributes: [:id, :level, :employee_master_id, :remark, :status, :_destroy]
    )

    permitted[:vendor_registration_ids] = Array(permitted[:vendor_registration_ids]).reject(&:blank?)
    permitted[:vendor_selection_criterion_ids] = Array(permitted[:vendor_selection_criterion_ids]).reject(&:blank?)
    permitted[:committee_steps_attributes] = normalize_nested_collection(permitted[:committee_steps_attributes])
    permitted
  end

  def normalize_nested_collection(attributes)
    case attributes
    when ActionController::Parameters
      attributes.to_h.values.map { |value| value.respond_to?(:to_h) ? value.to_h : value }
    when Hash
      attributes.values.map { |value| value.respond_to?(:to_h) ? value.to_h : value }
    else
      attributes
    end
  end

  def extract_nested_collection!(attributes, key)
    value = attributes.delete(key) || attributes.delete(key.to_sym)
    Array(value)
  end

  def raw_quotation_item_attributes
    raw_attributes = params.require(:quotation_proposal)[:quotation_proposal_items_attributes]
    return [] if raw_attributes.blank?

    case raw_attributes
    when ActionController::Parameters
      raw_attributes.to_unsafe_h.values
    when Hash
      raw_attributes.values
    else
      Array(raw_attributes)
    end
  end

  def build_quotation_items(quotation_proposal, item_attributes)
    Array(item_attributes).each do |attributes|
      item_params = normalize_item_attributes(attributes)
      next if skip_item_attributes?(item_params)

      quotation_proposal.quotation_proposal_items.build(item_params.except("id", "_destroy"))
    end
  end

  def sync_quotation_items(quotation_proposal, item_attributes)
    existing_items = quotation_proposal.quotation_proposal_items.index_by { |item| item.id.to_s }

    Array(item_attributes).each do |attributes|
      item_params = normalize_item_attributes(attributes)
      item_id = item_params["id"].to_s

      if ActiveModel::Type::Boolean.new.cast(item_params["_destroy"])
        existing_items[item_id]&.destroy! if item_id.present?
        next
      end

      next if skip_item_attributes?(item_params)

      payload = item_params.slice("item_name", "unit_id", "quantity", "max_rate", "remark")

      if item_id.present? && existing_items[item_id]
        existing_items[item_id].update!(payload)
      else
        quotation_proposal.quotation_proposal_items.create!(payload)
      end
    end
  end

  def normalize_item_attributes(attributes)
    case attributes
    when ActionController::Parameters
      attributes.to_h.stringify_keys
    when Hash
      attributes.stringify_keys
    else
      {}
    end
  end

  def skip_item_attributes?(item_params)
    return true if item_params.blank?

    item_params["item_name"].blank? &&
      item_params["unit_id"].blank? &&
      item_params["quantity"].blank? &&
      item_params["remark"].blank?
  end

  def quotation_scope
    QuotationProposal.includes(
      :theme,
      :vendor_registrations,
      { committee_steps: :employee_master },
      { quotation_proposal_vendors: [:vendor_registration, :committee_member_scores, { vendor_items: { quotation_proposal_item: :unit } }] },
      approval_request: { approval_steps: :employee_master }
    )
  end

  def own_quotation_scope
    return quotation_scope if admin_user?

    quotation_scope.where(user_id: current_user.id)
  end

  def can_access_menu?(identifier)
    return true if admin_user?
    return finance_queue_access? if identifier == "payment_advice_queue"

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
      return true if finance_queue_access?
    end

    role_permissions.find_by(menu_identifier: identifier)&.can_view? || false
  end

  def authorize_quotation_form_access!
    return if can_access_menu?("quotation_proposal_form") && quotation_maker_eligible?

    redirect_to root_path, alert: "You are not authorized to access Quotation Proposal form."
  end

  def authorize_quotation_list_access!
    return if can_access_menu?("quotation_proposal_list") || can_access_menu?("quotation_proposal_form")

    redirect_to root_path, alert: "You are not authorized to view Quotation Proposal list."
  end

  def authorize_payment_advice_access!
    return if finance_queue_access?

    redirect_to root_path, alert: "You are not authorized to view Payment Advice Queue."
  end

  def quotation_maker_eligible?
    return true if admin_user?

    current_user.vendor_registrations.exists?
  end

  def authorize_quotation_view_access!
    return if admin_user?
    return if @quotation_proposal.user_id == current_user.id
    return if @quotation_proposal.committee_user?(current_user)
    return if @quotation_proposal.approval_request&.approval_steps&.any? { |step| employee_matches_current_login?(step.employee_master) }

    redirect_to root_path, alert: "You are not authorized to view this Quotation Proposal."
  end

  def ensure_quotation_owner_access!
    return if admin_user? || @quotation_proposal.user_id == current_user.id

    redirect_to list_quotation_proposals_path, alert: "Only the creator can perform this action on the quotation proposal."
  end

  def ensure_quotation_change_allowed!
    return unless @quotation_proposal.approval_locked?

    redirect_to quotation_proposal_path(@quotation_proposal),
                alert: "Approved quotation proposals cannot be edited or deleted."
  end

  def load_form_collections
    stakeholder_id = quotation_form_stakeholder_id

    @themes = Theme.includes(:stakeholder_category)
    @themes = @themes.where(stakeholder_category_id: stakeholder_id) if stakeholder_id.present?
    @themes = @themes.order(:name)

    @units = Unit.order(:name)
    @products = Product.includes(:theme).order(:name)
    @product_varieties = ProductVariety.includes(product: :theme).order(:name)
    @vendors = VendorRegistration
      .includes(:themes, :approval_request)
      .joins(:approval_request)
      .where(approval_requests: { status: "approved" })
    @vendors = @vendors.where(stakeholder_category_id: [stakeholder_id, nil]) if stakeholder_id.present?
    @vendors = @vendors.distinct
      .order(:vendor_name)
    @vendor_selection_criteria = VendorSelectionCriterion
      .includes(:theme)
      .where(theme_id: @themes.select(:id))
      .joins(:theme)
      .order("themes.name ASC, vendor_selection_criteria.criteria ASC")
    maker_employee_ids = [
      @quotation_proposal&.user&.employee_master&.id,
      current_employee_master&.id
    ].compact.uniq
    @committee_members = EmployeeMaster.where.not(id: maker_employee_ids).order(:name)
  end

  def persist_quotation_proposal_with_criteria(quotation_proposal, selected_criteria_ids)
    QuotationProposal.transaction do
      quotation_proposal.save!
      quotation_proposal.sync_vendor_selection_criteria!(selected_criteria_ids)
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    attach_record_errors(quotation_proposal, error.record)
    false
  end

  def update_quotation_proposal_with_criteria(quotation_proposal, attrs, item_attributes, selected_criteria_ids)
    QuotationProposal.transaction do
      quotation_proposal.update!(attrs)
      sync_quotation_items(quotation_proposal, item_attributes)
      quotation_proposal.sync_vendor_selection_criteria!(selected_criteria_ids)
    end
    true
  rescue ActiveRecord::RecordInvalid => error
    attach_record_errors(quotation_proposal, error.record)
    false
  end

  def attach_record_errors(target_record, error_record)
    return if error_record.blank? || error_record == target_record

    message = error_record.errors.full_messages.to_sentence.presence
    target_record.errors.add(:base, message) if message.present?
  end

  def extract_vendor_selection_criterion_ids!(attributes)
    value = attributes.delete("vendor_selection_criterion_ids") || attributes.delete(:vendor_selection_criterion_ids)
    Array(value).reject(&:blank?).map(&:to_i).uniq
  end

  def raw_committee_criteria_scores
    criteria_scores = params[:committee_criteria_scores]

    case criteria_scores
    when ActionController::Parameters
      criteria_scores.to_unsafe_h
    when Hash
      criteria_scores
    else
      {}
    end
  end

  def raw_committee_remarks
    remarks = params[:committee_remarks]

    case remarks
    when ActionController::Parameters
      remarks.to_unsafe_h
    when Hash
      remarks
    else
      {}
    end
  end

  def sync_committee_criteria_scores(actor_employee)
    available_selection_ids = @quotation_proposal.criteria_selections.pluck(:id)
    submitted_scores = raw_committee_criteria_scores
    submitted_remarks = raw_committee_remarks
    updated = 0

    @quotation_proposal.quotation_proposal_vendors.find_each do |proposal_vendor|
      next unless proposal_vendor.response_submitted?

      score_payload = submitted_scores[proposal_vendor.id.to_s]
      updated += proposal_vendor.sync_committee_criteria_scores!(
        employee: actor_employee,
        available_selection_ids: available_selection_ids,
        score_by_selection_id: score_payload
      )

      score_record = proposal_vendor.committee_member_scores.find_or_initialize_by(employee_master: actor_employee)
      remark_value = submitted_remarks[proposal_vendor.id.to_s].to_s.strip.presence
      if score_record.remark != remark_value
        score_record.remark = remark_value
        score_record.save! if score_record.new_record? || score_record.changed?
        updated += 1
      end
    end

    updated
  end

  def quotation_form_stakeholder_id
    return @quotation_proposal.theme&.stakeholder_category_id if @quotation_proposal&.theme&.stakeholder_category_id.present?

    if @quotation_proposal&.theme_id.present?
      theme_stakeholder_id = Theme.where(id: @quotation_proposal.theme_id).pick(:stakeholder_category_id)
      return theme_stakeholder_id if theme_stakeholder_id.present?
    end

    return current_employee_master.stakeholder_category_id if current_employee_master&.stakeholder_category_id.present?

    current_user&.vendor_registrations&.where.not(stakeholder_category_id: nil)&.order(:id)&.pick(:stakeholder_category_id)
  end

  def load_purchase_order_context!
    @selected_proposal_vendor = @quotation_proposal.quotation_proposal_vendors
      .includes(
        :vendor_registration,
        :purchase_order_authorized_by,
        :purchase_order_reply_updated_by,
        purchase_order_activities: :employee_master,
        vendor_items: { quotation_proposal_item: :unit },
        invoice_requests: [:assets, { vendor_invoices_attachments: :blob }]
      )
      .find_by(vendor_registration_id: @quotation_proposal.selected_vendor_registration_id)

    if @selected_proposal_vendor.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Selected vendor response was not found for purchase order."
      return
    end

    vendor_remark_lines = @selected_proposal_vendor.vendor_remark.to_s.lines.map(&:strip).reject(&:blank?)
    @po_payment_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("payment terms and condition:") }&.split(":", 2)&.last.to_s.strip
    @po_completion_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("date of completion:") }&.split(":", 2)&.last.to_s.strip
    @po_warranty_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("warranty period:") }&.split(":", 2)&.last.to_s.strip
    @po_earnest_money_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("ernest money deposit:") || line.downcase.start_with?("earnest money deposit:") }&.split(":", 2)&.last.to_s.strip
    current_year = Date.current.year
    next_year_short = (current_year + 1).to_s.last(2)
    @purchase_order_year_label = "#{current_year}-#{next_year_short}"
    stakeholder_code = @quotation_proposal.theme&.stakeholder_category&.name.to_s.strip.presence || "ASA"
    @purchase_order_number = "#{stakeholder_code}/PO/#{@quotation_proposal.id}/#{@purchase_order_year_label}"
    @authorized_by_options = EmployeeMaster.order(:name)
    @purchase_order_authorized_by_locked = @selected_proposal_vendor.purchase_order_sent_at.present? && @selected_proposal_vendor.purchase_order_authorized_by.present?
    @authorized_by =
      if @purchase_order_authorized_by_locked
        @selected_proposal_vendor.purchase_order_authorized_by
      else
        @authorized_by_options.find_by(id: params[:authorized_by_id]) || @selected_proposal_vendor.purchase_order_authorized_by || current_employee_master
      end
    @purchase_order_due_date = params[:purchase_order_due_date].presence || @selected_proposal_vendor.purchase_order_due_date
  end

  def load_goods_receive_context!
    @goods_receive_vendor = @quotation_proposal.quotation_proposal_vendors
      .includes(:vendor_registration, vendor_items: { quotation_proposal_item: :unit }, invoice_requests: [:assets, { vendor_invoices_attachments: :blob }])
      .find_by(vendor_registration_id: @quotation_proposal.selected_vendor_registration_id)

    if @goods_receive_vendor.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Selected vendor was not found for goods receive."
      return
    end

    unless @goods_receive_vendor.purchase_order_status == "accepted"
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Goods receive can be updated only after the purchase order is accepted."
      return
    end
  end

  def load_invoice_request_asset_context!
    @invoice_request = QuotationProposalVendorInvoiceRequest
      .includes(
        :assets,
        quotation_proposal_vendor: [
          :vendor_registration,
          { vendor_items: { quotation_proposal_item: :unit } }
        ]
      )
      .find_by(id: params[:invoice_request_id], quotation_proposal_vendor_id: @quotation_proposal.quotation_proposal_vendors.select(:id))

    if @invoice_request.blank?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Invoice request was not found."
      return
    end

    unless @invoice_request.accepted?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Assets can be created only after maker accepts the uploaded invoice."
      return
    end

    if @invoice_request.assets_created?
      redirect_to quotation_proposal_path(@quotation_proposal), alert: "Assets have already been created for this invoice request."
    end
  end

  def parse_purchase_order_due_date
    raw_value = params[:purchase_order_due_date].presence
    return @selected_proposal_vendor.purchase_order_due_date if raw_value.blank?

    Date.parse(raw_value)
  rescue ArgumentError
    nil
  end

  def actor_display_name
    current_employee_master&.name.presence || current_user&.email.to_s
  end

  def actor_role_label
    return "Maker" if current_user == @quotation_proposal.user
    return "Committee" if @quotation_proposal.committee_user?(current_user)

    "System"
  end

  def parse_boolean_param(value)
    return true if value == "yes"
    return false if value == "no"

    nil
  end

  def build_received_batch_item(vendor_item, receive_now_quantity)
    {
      vendor_item_id: vendor_item.id,
      quotation_proposal_item_id: vendor_item.quotation_proposal_item_id,
      item_name: vendor_item.item_name,
      unit_name: vendor_item.unit&.name,
      ordered_quantity: vendor_item.quantity.to_s,
      received_quantity: receive_now_quantity.to_s,
      cumulative_received_quantity: (vendor_item.received_quantity.to_d + receive_now_quantity).to_s
    }
  end

  def goods_receive_invoice_note_for(received_batch_items)
    summary = received_batch_items.map do |item|
      "#{item[:item_name]} #{item[:received_quantity]} #{item[:unit_name]}".strip
    end.join(", ")
    "Goods received and invoice requested for: #{summary}"
  end

  def parse_finance_date(raw_value)
    return if raw_value.blank?

    Date.parse(raw_value.to_s)
  rescue ArgumentError
    nil
  end

  def finance_transaction_columns_available?
    required_columns = %w[transaction_type transaction_no transaction_date]
    required_columns.all? { |column_name| QuotationProposalVendorInvoiceRequest.column_names.include?(column_name) }
  end

  def build_invoice_request_asset_rows(invoice_request)
    rows = []
    suggested_stakeholder_id =
      invoice_request.quotation_proposal_vendor.quotation_proposal.theme&.stakeholder_category_id ||
      invoice_request.quotation_proposal_vendor.vendor_registration&.stakeholder_category_id

    invoice_request.snapshot_items.each do |item|
      vendor_item = invoice_request.quotation_proposal_vendor.vendor_items.find { |record| record.id == item[:vendor_item_id].to_i }
      next unless vendor_item&.fixed_asset == true

      suggested_product = Product.find_by(name: item[:item_name])
      quantity_count = item[:received_quantity].to_d.to_i

      quantity_count.times do |index|
        rows << {
          vendor_item_id: vendor_item.id,
          asset_name: item[:item_name],
          suggested_product_id: suggested_product&.id,
          stakeholder_category_id: suggested_stakeholder_id,
          primary_office_category_id: nil,
          secondary_office_category_id: nil,
          asset_code_date: nil,
          unit_name: item[:unit_name],
          row_label: "#{item[:item_name]} ##{index + 1}",
          unique_product_code: suggested_product&.product_code
        }
      end
    end

    if rows.blank? && invoice_request.uploaded?
      invoice_request.snapshot_items.each do |item|
        vendor_item = invoice_request.quotation_proposal_vendor.vendor_items.find { |record| record.id == item[:vendor_item_id].to_i }
        next unless vendor_item

        suggested_product = Product.find_by(name: item[:item_name])
        quantity_count = [item[:received_quantity].to_d.to_i, 1].max

        quantity_count.times do |index|
          rows << {
            vendor_item_id: vendor_item.id,
            asset_name: item[:item_name],
            suggested_product_id: suggested_product&.id,
            stakeholder_category_id: suggested_stakeholder_id,
            primary_office_category_id: nil,
            secondary_office_category_id: nil,
            asset_code_date: nil,
            unit_name: item[:unit_name],
            row_label: "#{item[:item_name]} ##{index + 1}",
            unique_product_code: suggested_product&.product_code
          }
        end
      end
    end

    rows
  end

  def asset_row_params
    params.fetch(:asset_rows, {}).permit!.to_h.values.map do |row|
      row.to_h.symbolize_keys
    end
  end

  def build_committee_steps(quotation_proposal)
    existing_levels = quotation_proposal.committee_steps.reject(&:marked_for_destruction?).map(&:level)

    (1..QuotationProposal::DEFAULT_COMMITTEE_MEMBERS).each do |level|
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
    return if committee_scoring_allowed_for?(@quotation_proposal)

    redirect_to quotation_proposal_path(@quotation_proposal), alert: "Only committee members can score vendors and select the final vendor."
  end

  def committee_scoring_allowed_for?(quotation_proposal)
    return false if quotation_proposal.blank?

    step_scope = if quotation_proposal.approval_request.present?
      quotation_proposal.approval_request.approval_steps.includes(:employee_master)
    else
      quotation_proposal.committee_steps.includes(:employee_master)
    end

    step_scope.any? { |step| employee_matches_current_login?(step.employee_master) }
  end

  def sms_delivery_failure_alert(default_message)
    sms_error = QuotationVendorSmsGateway.last_error_message
    [default_message, sms_error].compact.join(" ")
  end

end
