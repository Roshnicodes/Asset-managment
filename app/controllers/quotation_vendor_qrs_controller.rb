class QuotationVendorQrsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :load_vendor_access, except: :approved_link
  layout "public_qr"

  def approved_link
    proposal_vendor_id, quotation_proposal_id = approved_link_ids(params[:encoded_reference])
    proposal_vendor = QuotationProposalVendor.find_by(id: proposal_vendor_id, quotation_proposal_id: quotation_proposal_id)

    unless proposal_vendor
      flash.now[:alert] = "This vendor quotation link is invalid or no longer available."
      render :invalid_link, status: :not_found
      return
    end

    proposal_vendor.ensure_qr_token!
    redirect_to quotation_vendor_qr_path(proposal_vendor.qr_token)
  end

  def show
    return unless ensure_vendor_response_open!

    @quotation_vendor_dispatch.update!(last_opened_at: Time.current)
    clear_vendor_access_session! unless direct_maker_access_allowed? || (params[:verified] == "1" && vendor_access_allowed?)
    @otp_verified_for_render = direct_maker_access_allowed?
    auto_send_otp_if_needed!
    @otp_verified_for_render = true if direct_maker_access_allowed?
    @otp_verified_for_render = params[:verified] == "1" && vendor_access_allowed? unless direct_maker_access_allowed?
  end

  def send_otp
    return unless ensure_vendor_response_open!
    if direct_maker_access_allowed?
      redirect_to quotation_vendor_qr_path(params[:token], verified: 1, direct_access: 1), alert: "OTP is not required for direct maker access."
      return
    end

    @quotation_vendor_dispatch.update!(last_opened_at: Time.current, access_granted: false, access_expires_at: nil)
    @quotation_vendor_dispatch.send_new_otp!
    redirect_to quotation_vendor_qr_path(params[:token], skip_auto_otp: 1), notice: "A new OTP has been sent to the vendor mobile number."
  rescue QuotationVendorDispatch::SmsDeliveryError => error
    redirect_to quotation_vendor_qr_path(params[:token], skip_auto_otp: 1), alert: error.message
  end

  def verify_otp
    return unless ensure_vendor_response_open!
    if direct_maker_access_allowed?
      redirect_to quotation_vendor_qr_path(params[:token], verified: 1, direct_access: 1), alert: "OTP verification is not required for direct maker access."
      return
    end

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

    unless direct_maker_access_allowed? || vendor_access_allowed?
      redirect_to quotation_vendor_qr_path(params[:token]), alert: "Your OTP session has expired. Please request and verify a new OTP."
      return
    end

    unless direct_maker_access_allowed? || params[:asa_terms_accepted].to_s == "1"
      redirect_to quotation_vendor_qr_path(params[:token], verified: 1), alert: "Please accept the General Terms and Conditions before submitting the form."
      return
    end

    was_response_submitted = @quotation_proposal_vendor.response_submitted?
    pricing_before = vendor_pricing_snapshot(@quotation_proposal_vendor)

    if @quotation_proposal_vendor.update(vendor_response_params)
      if @quotation_proposal.missing_max_rates?
        @quotation_vendor_dispatch.update!(
          status: "draft_saved",
          access_granted: true,
          access_expires_at: 5.minutes.from_now,
          otp_verified_at: Time.current
        )
        NotificationDispatcher.notify_quotation_max_rate_required(@quotation_proposal, @quotation_proposal_vendor)

        redirect_target =
          if direct_maker_access_allowed?
            quotation_vendor_qr_path(params[:token], verified: 1, direct_access: 1)
          else
            quotation_vendor_qr_path(params[:token], verified: 1)
          end

        redirect_to redirect_target, alert: "The max rate is still pending. Your response was saved, but it was not finally submitted. The maker has been notified."
        return
      end

      response_received_at = Time.current
      @quotation_proposal_vendor.update!(response_status: "responded", responded_at: response_received_at)
      @quotation_proposal.set_quotation_validity_from!(response_received_at)
      if was_response_submitted && pricing_before != vendor_pricing_snapshot(@quotation_proposal_vendor)
        @quotation_proposal.invalidate_reused_quotations!
      end
      @quotation_vendor_dispatch.update!(
        status: "responded",
        access_granted: true,
        access_expires_at: 5.minutes.from_now,
        otp_verified_at: Time.current
      )
      if @quotation_proposal.below_10k?
        @quotation_proposal.quotation_proposal_vendors.where.not(id: @quotation_proposal_vendor.id).update_all(selected: false)
        @quotation_proposal_vendor.update!(selected: true)
        @quotation_proposal.update!(selected_vendor_registration: @vendor_registration)
      end
      @quotation_proposal.refresh_response_status!
      NotificationDispatcher.notify_quotation_vendor_response_received(@quotation_proposal, @quotation_proposal_vendor)
      if direct_maker_access_allowed?
        maker_notice = if @quotation_proposal.below_10k?
          "Quotation details have been submitted and approved successfully."
        else
          "Physical quotation details have been recorded successfully."
        end
        redirect_to quotation_proposal_path(@quotation_proposal), notice: maker_notice
      else
        redirect_to print_quotation_vendor_qr_path(params[:token]), notice: "Your quotation response has been submitted successfully. You can now print or save it as a PDF."
      end
    else
      @otp_verified_for_render = direct_maker_access_allowed? || true
      render :show, status: :unprocessable_entity
    end
  end

  private

  def approved_link_ids(encoded_reference)
    return [params[:v], params[:qp]] if params[:v].present? && params[:qp].present?

    match = encoded_reference.to_s.match(/\Av:(\d+),qp:(\d+)\z/)
    return [nil, nil] unless match

    [match[1], match[2]]
  end

  def load_vendor_access
    token = params[:token].presence || params[:t]
    token = token.to_s.strip
    @quotation_proposal_vendor = QuotationProposalVendor
      .includes(
        quotation_proposal: [{ theme: :stakeholder_category }, { quotation_proposal_items: :unit }],
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
    @quotation_proposal_vendor.ensure_vendor_item_rows!
    @quotation_proposal_vendor.reload
    @quotation_vendor_dispatch = @quotation_proposal_vendor.dispatch_record!
  end

  def ensure_vendor_response_open!
    return true if @quotation_proposal.sent_to_vendors_at.present?
    return true if @quotation_vendor_dispatch.sent_at.present? && @quotation_proposal.committee_completed?

    flash.now[:alert] = "This quotation is not open for vendor response yet."
    render :invalid_link, status: :unprocessable_entity
    false
  end

  def auto_send_otp_if_needed!
    return if direct_maker_access_allowed?
    return if params[:skip_auto_otp] == "1"
    return if vendor_access_allowed?

    latest_otp = @quotation_vendor_dispatch.latest_active_otp
    return if latest_otp.present? && latest_otp.expires_at.present? && latest_otp.expires_at.future?

    @quotation_vendor_dispatch.send_new_otp!
    flash.now[:notice] = "An OTP has been sent to the vendor mobile number."
  rescue QuotationVendorDispatch::SmsDeliveryError => error
    flash.now[:alert] = error.message
  end

  def vendor_response_params
    params.require(:quotation_proposal_vendor).permit(
      :vendor_reference_no,
      :vendor_cover_note,
      :vendor_remark,
      vendor_documents: [],
      vendor_items_attributes: [:id, :quoted_rate, :gst_percentage, :remark]
    )
  end

  def vendor_pricing_snapshot(proposal_vendor)
    proposal_vendor.vendor_items.order(:quotation_proposal_item_id).pluck(:quotation_proposal_item_id, :quoted_rate, :gst_percentage).map do |item_id, quoted_rate, gst_percentage|
      [item_id, quoted_rate.to_d, gst_percentage.to_d]
    end
  end

  def direct_maker_access_allowed?
    return false unless params[:direct_access] == "1"
    return false unless current_user.present?
    return false unless @quotation_proposal.below_10k? || physical_quotation_entry_allowed?

    admin_user? || current_user == @quotation_proposal.user
  end

  # A maker may key in a physical quotation on the vendor's behalf, but only
  # once the committee has cleared the request - the same gate the
  # physical_quotation action applies before sending the maker here.
  def physical_quotation_entry_allowed?
    params[:physical_entry] == "1" && @quotation_proposal.committee_completed?
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
