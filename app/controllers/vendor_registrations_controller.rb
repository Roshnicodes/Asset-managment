class VendorRegistrationsController < ApplicationController
  before_action :set_vendor_registration, only: %i[ show edit update destroy ]
  before_action :ensure_vendor_registration_editable!, only: %i[edit update]

  # GET /vendor_registrations or /vendor_registrations.json
  def index
    sync_vendor_approval_requests!

    base_scope = VendorRegistration.includes(
      :stakeholder_category,
      :registration_type,
      :firm,
      :state,
      :district,
      :block,
      approval_request: :approval_steps
    )

    if current_user.email == "admin@example.com" || current_user.employee_master&.user_type == "Admin"
      @vendor_registrations = base_scope.order(created_at: :desc)
    else
      @vendor_registrations = base_scope.where(user_id: current_user.id).order(created_at: :desc)
    end

  end

  def list
    sync_vendor_approval_requests!

    base_scope = VendorRegistration.includes(
      :stakeholder_category,
      :registration_type,
      :firm,
      :state,
      :district,
      :block,
      approval_request: :approval_steps
    )

    if current_user.email == "admin@example.com" || current_user.employee_master&.user_type == "Admin"
      @vendor_registrations = base_scope.joins(:approval_request).distinct.order(created_at: :desc)
    else
      own_ids = base_scope.where(user_id: current_user.id).joins(:approval_request).select(:id)
      involved_ids = if current_employee_master.present?
        VendorRegistration.joins(approval_request: :approval_steps)
          .where(approval_steps: { employee_master_id: current_employee_master.id })
          .select(:id)
      else
        VendorRegistration.none.select(:id)
      end
      configured_ids = if current_employee_master.present?
        VendorRegistration.joins(approval_request: { approval_channel: :approval_channel_steps })
          .where(approval_channel_steps: { to_responsible_user_id: current_employee_master.id })
          .select(:id)
      else
        VendorRegistration.none.select(:id)
      end

      @vendor_registrations = base_scope.where(id: own_ids)
        .or(base_scope.where(id: involved_ids))
        .or(base_scope.where(id: configured_ids))
        .distinct
        .order(created_at: :desc)
    end
  end

  # POST /vendor_registrations/send_for_approval
  def send_for_approval
    vendor_ids = if params[:id].present?
      [params[:id]]
    else
      Array(params[:vendor_registration_ids]).reject(&:blank?)
    end

    if vendor_ids.present?
      sent_count = 0
      failed_count = 0

      VendorRegistration.where(id: vendor_ids).each do |vendor|
        next if vendor.approval_request.present?

        approval_request = ApprovalRequestBuilder.create_for!(vendor, form_name: "Vendor Registration")
        approval_request.present? ? sent_count += 1 : failed_count += 1
      end

      if sent_count.positive? && failed_count.zero?
        redirect_to list_vendor_registrations_path, notice: "Selected Vendor Registrations sent for approval successfully."
      elsif sent_count.positive?
        redirect_to list_vendor_registrations_path, alert: "#{sent_count} registration(s) sent for approval, but #{failed_count} could not be mapped to a valid approval channel."
      else
        redirect_to vendor_registrations_path, alert: "No approval request was created. Please check Theme, Stakeholder, and Approval Channel steps."
      end
    else
      redirect_to vendor_registrations_path, alert: "No Vendor Registrations were selected."
    end
  end

  # GET /vendor_registrations/1 or /vendor_registrations/1.json
  def show
    @vendor_registration.approval_request&.ensure_channel_steps_synced!
  end

  # GET /vendor_registrations/new
  def new
    @vendor_registration = VendorRegistration.new
    load_form_collections
    @vendor_registration.vendor_bank_masters.build if @vendor_registration.vendor_bank_masters.empty?
  end

  # GET /vendor_registrations/1/edit
  def edit
    load_form_collections
    @vendor_registration.vendor_bank_masters.build if @vendor_registration.vendor_bank_masters.empty?
  end

  # POST /vendor_registrations or /vendor_registrations.json
  def create
    permitted_params = vendor_registration_params
    @vendor_registration = VendorRegistration.new(permitted_params.except(:document_uploads))
    @vendor_registration.incoming_document_files = permitted_params[:document_uploads]
    @vendor_registration.user = current_user
    @vendor_registration.submitted_at ||= Time.current
    @vendor_registration.submitted_ip ||= request.remote_ip

    respond_to do |format|
      if @vendor_registration.save
        ApprovalRequestBuilder.create_for!(@vendor_registration, form_name: "Vendor Registration")
        format.html { redirect_to vendor_registrations_path, notice: "Vendor registration was successfully created." }
        format.json { render :show, status: :created, location: @vendor_registration }
      else
        load_form_collections
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @vendor_registration.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /vendor_registrations/1 or /vendor_registrations/1.json
  def update
    permitted_params = vendor_registration_params
    @vendor_registration.incoming_document_files = permitted_params[:document_uploads]
    was_returned = @vendor_registration.approval_request&.employee_return_pending?

    respond_to do |format|
      if @vendor_registration.update(permitted_params.except(:document_uploads))
        @vendor_registration.approval_request&.resubmit_after_return! if was_returned

        notice_message = if was_returned
          "Vendor registration was updated and sent back for approval."
        else
          "Vendor registration was successfully updated."
        end

        format.html { redirect_to vendor_registrations_path, notice: notice_message, status: :see_other }
        format.json { render :show, status: :ok, location: @vendor_registration }
      else
        load_form_collections
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @vendor_registration.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /vendor_registrations/1 or /vendor_registrations/1.json
  def destroy
    if @vendor_registration.destroy
      respond_to do |format|
        format.html { redirect_to vendor_registrations_path, notice: "Vendor registration was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      end
    else
      message = @vendor_registration.errors.full_messages.to_sentence.presence || "Vendor registration could not be deleted."

      respond_to do |format|
        format.html { redirect_to vendor_registrations_path, alert: message, status: :see_other }
        format.json { render json: { error: message }, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::InvalidForeignKey
    message = "Vendor registration cannot be deleted because it is already linked to quotation proposals."

    respond_to do |format|
      format.html { redirect_to vendor_registrations_path, alert: message, status: :see_other }
      format.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_vendor_registration
      @vendor_registration = VendorRegistration.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def vendor_registration_params
      permitted_params = params.require(:vendor_registration).permit(
        :stakeholder_category_id, :registration_type_id, :firm_name, :firm_id, :vendor_name, :firm_type, :gst_no, :pan_no,
        :email, :mobile_no, :state_id, :district_id, :block_id, :pin_no, :contact_person_name,
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

    def load_form_collections
      @stakeholder_categories = StakeholderCategory.order(:name)
      @registration_types = RegistrationType.order(:name)
      @firms = Firm.order(:name)
      @document_masters = DocumentMaster.includes(:firm).order(:name)
      @states = State.order(:name)
      @districts = District.includes(:state).order(:name)
      @blocks = Block.includes(district: :state).order(:name)
      @themes = Theme.includes(products: :product_varieties).order(:name)
      @products = Product.includes(:theme).order(:name)
      @product_varieties = ProductVariety.includes(product: :theme).order(:name)
    end

    def ensure_vendor_registration_editable!
      return if current_user.email == "admin@example.com" || current_user.employee_master&.user_type == "Admin"
      return unless @vendor_registration.approval_request.present?
      return if @vendor_registration.approval_request.employee_return_pending?

      redirect_to vendor_registration_path(@vendor_registration), alert: "You can edit this vendor registration only after it is returned to the employee."
    end

    def sync_vendor_approval_requests!
      ApprovalRequest.sync_scope!(
        ApprovalRequest.includes(:approval_channel, :approvable, :approval_steps)
          .where(form_name: "Vendor Registration")
      )
    end

    def sync_approval_request_steps(vendor_registrations)
      vendor_registrations.each do |vendor_registration|
        vendor_registration.approval_request&.ensure_channel_steps_synced!
      end
    end
end
