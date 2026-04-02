class QuotationVendorQrsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :load_vendor_access
  layout "public_qr"

  def show
    return unless ensure_vendor_response_open!

    @quotation_vendor_dispatch.update!(last_opened_at: Time.current)
    clear_vendor_access_session! unless params[:verified] == "1" && vendor_access_allowed?
    @otp_verified_for_render = false
    auto_send_otp_if_needed!
    @otp_verified_for_render = params[:verified] == "1" && vendor_access_allowed?
  end

  def send_otp
    return unless ensure_vendor_response_open!

    @quotation_vendor_dispatch.update!(last_opened_at: Time.current, access_granted: false, access_expires_at: nil)
    @quotation_vendor_dispatch.send_new_otp!
    redirect_to quotation_vendor_qr_path(params[:token]), notice: "A new OTP has been sent to the vendor mobile number."
  end

  def verify_otp
    return unless ensure_vendor_response_open!

    if @quotation_vendor_dispatch.verify_otp!(params[:otp_code])
      mark_vendor_access_verified!
      redirect_to quotation_vendor_qr_path(params[:token], verified: 1), notice: "OTP verified successfully. You can now fill the quotation form."
    else
      @otp_verified_for_render = false
      flash.now[:alert] = "Invalid or expired OTP. Please request a new OTP."
      render :show, status: :unprocessable_entity
    end
  end

  def print
    return unless ensure_vendor_response_open!

    unless @quotation_proposal_vendor.response_submitted?
      redirect_to quotation_vendor_qr_path(params[:token]), alert: "Please submit your quotation response before printing."
      return
    end
  end

  def update
    return unless ensure_vendor_response_open!

    unless vendor_access_allowed?
      redirect_to quotation_vendor_qr_path(params[:token]), alert: "Your OTP session has expired. Please request and verify a new OTP."
      return
    end

    if @quotation_proposal_vendor.update(vendor_response_params)
      @quotation_proposal_vendor.update!(response_status: "responded", responded_at: Time.current)
      @quotation_vendor_dispatch.update!(
        status: "responded",
        access_granted: true,
        access_expires_at: 5.minutes.from_now,
        otp_verified_at: Time.current
      )
      @quotation_proposal.refresh_response_status!
      NotificationDispatcher.notify_quotation_vendor_response_received(@quotation_proposal, @quotation_proposal_vendor)
      redirect_to print_quotation_vendor_qr_path(params[:token]), notice: "Your quotation response has been submitted successfully. You can now print or save it as a PDF."
    else
      @otp_verified_for_render = true
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_vendor_access
    token = params[:token].to_s.strip
    @quotation_proposal_vendor = QuotationProposalVendor
      .includes(
        quotation_proposal: [:theme, { quotation_proposal_items: :unit }],
        vendor_registration: [],
        vendor_items: { quotation_proposal_item: :unit },
        vendor_dispatch: :quotation_vendor_otps
      )
      .find_by(qr_token: token)

    unless @quotation_proposal_vendor
      flash.now[:alert] = "This vendor quotation link is invalid or no longer available."
      render :invalid_link, status: :not_found
      return
    end

    @quotation_proposal = @quotation_proposal_vendor.quotation_proposal
    @vendor_registration = @quotation_proposal_vendor.vendor_registration
    @stakeholder_category = @quotation_proposal.theme&.stakeholder_category
    @quotation_vendor_dispatch = @quotation_proposal_vendor.dispatch_record!
  end

  def ensure_vendor_response_open!
    return true if @quotation_proposal.sent_to_vendors_at.present?

    redirect_to quotation_vendor_qr_path(params[:token]), alert: "This quotation is not open for vendor response yet."
    false
  end

  def auto_send_otp_if_needed!
    return if vendor_access_allowed?

    latest_otp = @quotation_vendor_dispatch.latest_active_otp
    return if latest_otp.present? && latest_otp.expires_at.present? && latest_otp.expires_at.future?

    @quotation_vendor_dispatch.send_new_otp!
    flash.now[:notice] = "An OTP has been sent to the vendor mobile number."
  end

  def vendor_response_params
    params.require(:quotation_proposal_vendor).permit(
      :vendor_remark,
      vendor_items_attributes: [:id, :quoted_rate, :gst_percentage, :remark]
    )
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
    "quotation_vendor_access_#{@quotation_vendor_dispatch.id}"
  end
end
