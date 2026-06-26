class VendorRegistrationInvitationsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[public_start public_lookup public_show send_otp verify_otp register]
  before_action :set_current_stakeholder_category, only: %i[new create]
  before_action :authorize_vendor_registration_maker_access!, only: %i[new create resend]
  before_action :set_invitation, only: %i[show resend]
  before_action :set_public_invitation, only: %i[public_show send_otp verify_otp register]
  layout :layout_for_action

  def new
    @invitation = VendorRegistrationInvitation.new
  end

  def create
    @invitation = VendorRegistrationInvitation.new(invitation_params)
    @invitation.user = current_user
    @invitation.stakeholder_category ||= @current_stakeholder_category

    if @invitation.save
      begin
        @invitation.send_registration_link!
        redirect_to vendor_registration_invitation_path(@invitation), notice: "Vendor registration SMS invite has been sent successfully."
      rescue VendorRegistrationInvitation::SmsDeliveryError => error
        redirect_to vendor_registration_invitation_path(@invitation), alert: error.message
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def resend
    @invitation.send_registration_link!
    redirect_to vendor_registration_invitation_path(@invitation), notice: "Vendor registration SMS invite has been sent again."
  rescue VendorRegistrationInvitation::SmsDeliveryError => error
    redirect_to vendor_registration_invitation_path(@invitation), alert: error.message
  end

  def public_start
    token = vendor_registration_query_token
    return if token.blank?

    invitation = VendorRegistrationInvitation.find_by(token: token)
    if invitation.present?
      redirect_to public_vendor_registration_invitation_path(invitation.token)
    else
      render :invalid_link, status: :not_found
    end
  end

  def public_lookup
    mobile_no = normalized_mobile_no(params[:mobile_no])
    @invitation = VendorRegistrationInvitation
      .where(mobile_no: mobile_no, vendor_registration_id: nil)
      .order(created_at: :desc)
      .first

    if @invitation.blank?
      flash.now[:alert] = "No active registration invite found for this mobile number. Please check the number or contact the team that shared the invite."
      render :public_start, status: :unprocessable_entity
      return
    end

    @invitation.send_new_otp!
    redirect_to public_vendor_registration_invitation_path(@invitation.token, skip_auto_otp: 1), notice: "An OTP has been sent to your mobile number."
  rescue VendorRegistrationInvitation::SmsDeliveryError => error
    redirect_to start_vendor_registration_invitation_path, alert: error.message
  end

  def public_show
    if @invitation.vendor_registration.present?
      render :success
      return
    end

    @invitation.mark_opened!
    prepare_public_registration_form if invitation_access_allowed?
    auto_send_otp_if_needed! unless invitation_access_allowed?
  end

  def send_otp
    @invitation.send_new_otp!
    redirect_to public_vendor_registration_invitation_path(@invitation.token, skip_auto_otp: 1), notice: "A new OTP has been sent to your mobile number."
  rescue VendorRegistrationInvitation::SmsDeliveryError => error
    redirect_to public_vendor_registration_invitation_path(@invitation.token, skip_auto_otp: 1), alert: error.message
  end

  def verify_otp
    if @invitation.verify_otp!(params[:otp_code])
      mark_invitation_access_verified!
      redirect_to public_vendor_registration_invitation_path(@invitation.token, verified: 1), notice: "OTP verified successfully. You can now complete vendor registration."
    else
      flash.now[:alert] = "Invalid or expired OTP. Please request a new OTP."
      render :public_show, status: :unprocessable_entity
    end
  end

  def register
    if @invitation.vendor_registration.present?
      render :success
      return
    end

    unless invitation_access_allowed?
      redirect_to public_vendor_registration_invitation_path(@invitation.token), alert: "Your OTP session has expired. Please request and verify a new OTP."
      return
    end

    permitted_params = vendor_registration_params
    @vendor_registration = VendorRegistration.new(permitted_params.except(:document_uploads))
    @vendor_registration.mobile_no = @invitation.mobile_no
    @vendor_registration.incoming_document_files = permitted_params[:document_uploads]
    @vendor_registration.submitted_at ||= Time.current
    @vendor_registration.submitted_ip ||= request.remote_ip

    if @vendor_registration.valid?
      VendorRegistration.transaction do
        @vendor_registration.save!
        ApprovalRequestBuilder.create_direct_finance_for_vendor_invitation!(@vendor_registration)
        @invitation.update!(vendor_registration: @vendor_registration, status: "registered")
      end
      render :success
    else
      load_form_collections
      @vendor_registration.vendor_bank_masters.build if @vendor_registration.vendor_bank_masters.empty?
      render :public_show, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound => error
    load_form_collections
    @vendor_registration ||= VendorRegistration.new(vendor_registration_params.except(:document_uploads))
    @vendor_registration.vendor_bank_masters.build if @vendor_registration.vendor_bank_masters.empty?
    @vendor_registration.errors.add(:base, error.message)
    render :public_show, status: :unprocessable_entity
  end

  private

  def authorize_vendor_registration_maker_access!
    return if vendor_registration_maker?

    redirect_to list_vendor_registrations_path,
                alert: "Only the Proposal Create maker can send vendor registration links."
  end

  def set_invitation
    scope = admin_user? ? VendorRegistrationInvitation.all : VendorRegistrationInvitation.where(user_id: current_user.id)
    @invitation = scope.find(params[:id])
  end

  def set_public_invitation
    @invitation = VendorRegistrationInvitation.find_by!(token: params[:token])
    @stakeholder_category = @invitation.stakeholder_category
  rescue ActiveRecord::RecordNotFound
    render :invalid_link, status: :not_found
  end

  def invitation_params
    params.require(:vendor_registration_invitation).permit(:mobile_no, :stakeholder_category_id)
  end

  def normalized_mobile_no(mobile_no)
    digits = mobile_no.to_s.gsub(/\D+/, "")
    digits = digits.delete_prefix("0") if digits.length == 11 && digits.start_with?("0")
    digits = digits.delete_prefix("91") if digits.length == 12 && digits.start_with?("91")
    digits
  end

  def vendor_registration_query_token
    return params[:t] if params[:t].present?

    query_string = request.query_string.to_s
    return if query_string.blank? || query_string.include?("=") || query_string.include?("&")

    query_string
  end

  def vendor_registration_params
    permitted_params = params.require(:vendor_registration).permit(
      :stakeholder_category_id, :registration_type_id, :firm_name, :firm_id, :vendor_name, :firm_type, :gst_no, :pan_no,
      :email, :mobile_no, :address, :state_id, :district_id, :block_id, :pin_no, :contact_person_name,
      :contact_person_designation, :msme, :msme_number, :company_status, :firm_profile, :business_description,
      :msme_certificate, :pan_document, :aadhar_document, :establishment_certificate,
      document_uploads: {},
      vendor_bank_masters_attributes: [:id, :bank_name, :bank_address, :ifsc_code, :account_number, :account_type, :cancelled_cheque, :_destroy],
      theme_ids: [], product_ids: [], product_variety_ids: []
    )

    %i[theme_ids product_ids product_variety_ids].each do |association_key|
      permitted_params[association_key] = Array(permitted_params[association_key]).reject(&:blank?)
    end

    permitted_params[:document_uploads] = permitted_params[:document_uploads].to_h if permitted_params[:document_uploads].present?
    permitted_params
  end

  def prepare_public_registration_form
    @vendor_registration ||= VendorRegistration.new(mobile_no: @invitation.mobile_no, stakeholder_category: @invitation.stakeholder_category)
    @vendor_registration.vendor_bank_masters.build if @vendor_registration.vendor_bank_masters.empty?
    load_form_collections
  end

  def auto_send_otp_if_needed!
    return if params[:skip_auto_otp] == "1"
    return if @invitation.otp_code.present? && @invitation.otp_expires_at.present? && @invitation.otp_expires_at.future?

    @invitation.send_new_otp!
    flash.now[:notice] = "An OTP has been sent to your mobile number."
  rescue VendorRegistrationInvitation::SmsDeliveryError => error
    flash.now[:alert] = error.message
  end

  def invitation_access_allowed?
    session[session_key_for_invitation_access] == true && @invitation.access_open?
  end

  def mark_invitation_access_verified!
    session[session_key_for_invitation_access] = true
  end

  def session_key_for_invitation_access
    "vendor_registration_invitation_access_#{@invitation.id}"
  end

  def load_form_collections
    @stakeholder_categories = @invitation.stakeholder_category.present? ? StakeholderCategory.where(id: @invitation.stakeholder_category_id) : StakeholderCategory.order(:name)
    @registration_types = RegistrationType.order(:name)
    @firms = Firm.order(:name)
    @document_masters = DocumentMaster.includes(:firm).order(:name)
    @states = State.order(:name)
    @districts = District.includes(:state).order(:name)
    @blocks = Block.includes(district: :state).order(:name)
    @district_filter_data = @districts.map do |district|
      { id: district.id, name: district.name, state_id: district.state_id }
    end
    @block_filter_data = @blocks.map do |block|
      { id: block.id, name: block.name, district_id: block.district_id, state_id: block.district&.state_id }
    end
    @themes = Theme.includes(products: :product_varieties).order(:name)
    @products = Product.includes(:theme).order(:name)
    @product_varieties = ProductVariety.includes(product: :theme).order(:name)
  end

  def set_current_stakeholder_category
    @current_stakeholder_category = current_employee_master&.stakeholder_category
  end

  def layout_for_action
    %w[public_start public_lookup public_show send_otp verify_otp register].include?(action_name) ? "public_qr" : "application"
  end
end
