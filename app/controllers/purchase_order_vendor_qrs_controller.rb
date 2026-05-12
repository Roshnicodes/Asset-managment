class PurchaseOrderVendorQrsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :load_purchase_order_access
  layout "public_qr"

  def show
    return unless ensure_purchase_order_open!

    @quotation_vendor_dispatch.update!(last_opened_at: Time.current)
    if @quotation_proposal_vendor.purchase_order_expired?
      @otp_verified_for_render = true
      return
    end

    clear_vendor_access_session! unless params[:verified] == "1" && vendor_access_allowed?
    auto_send_otp_if_needed!
    @otp_verified_for_render = params[:verified] == "1" && vendor_access_allowed?
  end

  def send_otp
    return unless ensure_purchase_order_open!
    if @quotation_proposal_vendor.purchase_order_expired?
      redirect_to purchase_order_vendor_qr_path(params[:token]), alert: "The purchase order response last date has passed."
      return
    end

    @quotation_vendor_dispatch.update!(last_opened_at: Time.current, access_granted: false, access_expires_at: nil)
    @quotation_vendor_dispatch.send_new_otp!(purpose: :purchase_order)
    redirect_to purchase_order_vendor_qr_path(params[:token], skip_auto_otp: 1), notice: "A new OTP has been sent to the vendor mobile number."
  rescue QuotationVendorDispatch::SmsDeliveryError => error
    redirect_to purchase_order_vendor_qr_path(params[:token], skip_auto_otp: 1), alert: error.message
  end

  def verify_otp
    return unless ensure_purchase_order_open!
    if @quotation_proposal_vendor.purchase_order_expired?
      redirect_to purchase_order_vendor_qr_path(params[:token]), alert: "The purchase order response last date has passed."
      return
    end

    if @quotation_vendor_dispatch.verify_otp!(params[:otp_code])
      mark_vendor_access_verified!
      redirect_to purchase_order_vendor_qr_path(params[:token], verified: 1), notice: "OTP verified successfully. You can now review the purchase order."
    else
      @otp_verified_for_render = false
      flash.now[:alert] = "Invalid or expired OTP. Please request a new OTP."
      render :show, status: :unprocessable_entity
    end
  end

  def update
    return unless ensure_purchase_order_open!
    if @quotation_proposal_vendor.purchase_order_expired?
      redirect_to purchase_order_vendor_qr_path(params[:token], verified: 1), alert: "The purchase order response last date has passed. You can no longer submit the form."
      return
    end

    unless vendor_access_allowed?
      redirect_to purchase_order_vendor_qr_path(params[:token]), alert: "Your OTP session has expired. Please request and verify a new OTP."
      return
    end

    decision = params[:purchase_order_decision].to_s
    remark = params[:purchase_order_remark].to_s.strip
    terms_accepted = params[:purchase_order_terms_accepted].to_s == "1"

    if decision.blank?
      redirect_to purchase_order_vendor_qr_path(params[:token], verified: 1), alert: "Please choose Accept, Return, or Reject."
      return
    end

    unless terms_accepted
      redirect_to purchase_order_vendor_qr_path(params[:token], verified: 1), alert: "Please accept the General Terms and Conditions before submitting the form."
      return
    end

    if remark.blank?
      redirect_to purchase_order_vendor_qr_path(params[:token], verified: 1), alert: "Remark is required for accept, return, or reject."
      return
    end

    if decision == "returned" && @quotation_proposal_vendor.purchase_order_returned_once?
      redirect_to purchase_order_vendor_qr_path(params[:token], verified: 1), alert: "Purchase order can be returned only once. Please accept or reject."
      return
    end

    @quotation_proposal_vendor.update!(
      purchase_order_status: decision,
      purchase_order_remark: remark.presence,
      purchase_order_actioned_at: Time.current
    )
    @quotation_proposal_vendor.add_purchase_order_activity!(
      action_type: "vendor_#{decision}",
      actor_name: @vendor_registration.display_name,
      actor_role: "Vendor",
      note: remark.presence || "Vendor marked the purchase order as #{decision.humanize.downcase}.",
      occurred_at: @quotation_proposal_vendor.purchase_order_actioned_at
    )
    @quotation_vendor_dispatch.update!(
      status: "purchase_order_#{decision}",
      access_granted: true,
      access_expires_at: 5.minutes.from_now,
      otp_verified_at: Time.current
    )
    NotificationDispatcher.notify_purchase_order_vendor_action(@quotation_proposal, @quotation_proposal_vendor)

    redirect_to purchase_order_vendor_qr_path(params[:token], verified: 1), notice: "Purchase order response has been submitted successfully."
  end

  private

  def load_purchase_order_access
    token = params[:token].to_s.strip
    @quotation_proposal_vendor = QuotationProposalVendor
      .includes(
        { quotation_proposal: [{ theme: :stakeholder_category }, { quotation_proposal_items: :unit }] },
        :vendor_registration,
        :purchase_order_authorized_by,
        { vendor_items: { quotation_proposal_item: :unit } },
        { vendor_dispatch: :quotation_vendor_otps }
      )
      .find_by(po_token: token)

    unless @quotation_proposal_vendor
      flash.now[:alert] = "This purchase order link is invalid or no longer available."
      render :invalid_link, status: :not_found
      return
    end

    @quotation_proposal = @quotation_proposal_vendor.quotation_proposal
    @vendor_registration = @quotation_proposal_vendor.vendor_registration
    @stakeholder_category = @quotation_proposal.theme&.stakeholder_category
    @quotation_vendor_dispatch = @quotation_proposal_vendor.dispatch_record!
    vendor_remark_lines = @quotation_proposal_vendor.vendor_remark.to_s.lines.map(&:strip).reject(&:blank?)
    @po_payment_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("payment terms and condition:") }&.split(":", 2)&.last.to_s.strip
    @po_completion_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("date of completion:") }&.split(":", 2)&.last.to_s.strip
    @po_warranty_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("warranty period:") }&.split(":", 2)&.last.to_s.strip
    @po_earnest_money_terms = vendor_remark_lines.find { |line| line.downcase.start_with?("ernest money deposit:") || line.downcase.start_with?("earnest money deposit:") }&.split(":", 2)&.last.to_s.strip
    current_year = Date.current.year
    next_year_short = (current_year + 1).to_s.last(2)
    @purchase_order_year_label = "#{current_year}-#{next_year_short}"
    @purchase_order_expired = @quotation_proposal_vendor.purchase_order_expired?
  end

  def ensure_purchase_order_open!
    return true if @quotation_proposal_vendor.purchase_order_sent?

    redirect_to purchase_order_vendor_qr_path(params[:token]), alert: "This purchase order is not open for vendor action yet."
    false
  end

  def auto_send_otp_if_needed!
    return if params[:skip_auto_otp] == "1"
    return if vendor_access_allowed?

    latest_otp = @quotation_vendor_dispatch.latest_active_otp
    return if latest_otp.present? && latest_otp.expires_at.present? && latest_otp.expires_at.future?

    @quotation_vendor_dispatch.send_new_otp!(purpose: :purchase_order)
    flash.now[:notice] = "An OTP has been sent to the vendor mobile number."
  rescue QuotationVendorDispatch::SmsDeliveryError => error
    flash.now[:alert] = error.message
  end

  def vendor_access_allowed?
    session[session_key_for_vendor_access] == true && @quotation_vendor_dispatch.access_open?
  end

  def mark_vendor_access_verified!
    session[session_key_for_vendor_access] = true
  end

  def clear_vendor_access_session!
    session.delete(session_key_for_vendor_access)
  end

  def session_key_for_vendor_access
    "purchase_order_vendor_access_#{@quotation_vendor_dispatch.id}"
  end
end
