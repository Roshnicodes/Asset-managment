class GoodsReceiveVendorQrsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :load_invoice_request_access
  layout "public_qr"

  def show
    @quotation_vendor_dispatch.update!(last_opened_at: Time.current)
    clear_vendor_access_session! unless params[:verified] == "1" && vendor_access_allowed?
    auto_send_otp_if_needed!
    @otp_verified_for_render = params[:verified] == "1" && vendor_access_allowed?
  end

  def send_otp
    @quotation_vendor_dispatch.update!(last_opened_at: Time.current, access_granted: false, access_expires_at: nil)
    @quotation_vendor_dispatch.send_new_otp!(purpose: :invoice)
    redirect_to goods_receive_vendor_qr_path(params[:token], skip_auto_otp: 1), notice: "A new OTP has been sent to the vendor mobile number."
  rescue QuotationVendorDispatch::SmsDeliveryError => error
    redirect_to goods_receive_vendor_qr_path(params[:token], skip_auto_otp: 1), alert: error.message
  end

  def verify_otp
    if @quotation_vendor_dispatch.verify_otp!(params[:otp_code])
      mark_vendor_access_verified!
      redirect_to goods_receive_vendor_qr_path(params[:token], verified: 1), notice: "OTP verified successfully. You can now upload the invoice."
    else
      @otp_verified_for_render = false
      flash.now[:alert] = "Invalid or expired OTP. Please request a new OTP."
      render :show, status: :unprocessable_entity
    end
  end

  def update
    unless vendor_access_allowed?
      redirect_to goods_receive_vendor_qr_path(params[:token]), alert: "Your OTP session has expired. Please request and verify a new OTP."
      return
    end

    if @invoice_request.accepted?
      redirect_to goods_receive_vendor_qr_path(params[:token], verified: 1), alert: "This invoice has already been accepted."
      return
    end

    if @invoice_request.uploaded?
      redirect_to goods_receive_vendor_qr_path(params[:token], verified: 1), alert: "Invoice has already been uploaded and is pending maker review."
      return
    end

    uploaded_files = Array(params.dig(:invoice_request, :vendor_invoices)).compact_blank
    vendor_remark = params.dig(:invoice_request, :vendor_remark).to_s.strip

    if uploaded_files.blank?
      redirect_to goods_receive_vendor_qr_path(params[:token], verified: 1), alert: "Please upload at least one invoice document."
      return
    end

    was_returned = @invoice_request.returned?
    @invoice_request.vendor_invoices.attach(uploaded_files)
    @invoice_request.update!(
      status: "uploaded",
      vendor_remark: vendor_remark.presence,
      invoice_uploaded_at: Time.current,
      maker_review_remark: nil,
      maker_reviewed_at: nil,
      maker_reviewed_by: nil,
      returned_at: nil,
      accepted_at: nil
    )

    @quotation_proposal_vendor.add_purchase_order_activity!(
      action_type: was_returned ? "goods_receive_invoice_reuploaded" : "goods_receive_invoice_uploaded",
      actor_name: @vendor_registration.display_name,
      actor_role: "Vendor",
      note: goods_receive_invoice_uploaded_note(@invoice_request),
      occurred_at: @invoice_request.invoice_uploaded_at
    )

    @quotation_vendor_dispatch.update!(
      status: "goods_receive_invoice_uploaded",
      access_granted: true,
      access_expires_at: 5.minutes.from_now,
      otp_verified_at: Time.current
    )

    NotificationDispatcher.notify_goods_receive_invoice_uploaded(@quotation_proposal, @quotation_proposal_vendor, @invoice_request)
    redirect_to goods_receive_vendor_qr_path(params[:token], verified: 1), notice: "Invoice has been uploaded successfully."
  end

  private

  def load_invoice_request_access
    token = params[:token].to_s.strip
    @invoice_request = QuotationProposalVendorInvoiceRequest
      .includes(
        { vendor_invoices_attachments: :blob },
        quotation_proposal_vendor: [
          :vendor_registration,
          :purchase_order_authorized_by,
          { quotation_proposal: { theme: :stakeholder_category } },
          { vendor_items: { quotation_proposal_item: :unit } },
          { vendor_dispatch: :quotation_vendor_otps }
        ]
      )
      .find_by(request_token: token)

    unless @invoice_request
      flash.now[:alert] = "This goods receive invoice link is invalid or no longer available."
      render :invalid_link, status: :not_found
      return
    end

    @quotation_proposal_vendor = @invoice_request.quotation_proposal_vendor
    @quotation_proposal = @quotation_proposal_vendor.quotation_proposal
    @vendor_registration = @quotation_proposal_vendor.vendor_registration
    @stakeholder_category = @quotation_proposal.theme&.stakeholder_category
    @quotation_vendor_dispatch = @quotation_proposal_vendor.dispatch_record!
  end

  def auto_send_otp_if_needed!
    return if params[:skip_auto_otp] == "1"
    return if vendor_access_allowed?

    latest_otp = @quotation_vendor_dispatch.latest_active_otp
    return if latest_otp.present? && latest_otp.expires_at.present? && latest_otp.expires_at.future?

    @quotation_vendor_dispatch.send_new_otp!(purpose: :invoice)
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
    "goods_receive_vendor_access_#{@quotation_vendor_dispatch.id}_#{@invoice_request.id}"
  end

  def goods_receive_invoice_uploaded_note(invoice_request)
    summary = invoice_request.snapshot_items.map do |item|
      "#{item[:item_name]} #{item[:received_quantity]} #{item[:unit_name]}".strip
    end.join(", ")
    note = "Invoice uploaded for received goods: #{summary}"
    return note if invoice_request.vendor_remark.blank?

    "#{note}. Remark: #{invoice_request.vendor_remark}"
  end
end
