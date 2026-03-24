class VendorRegistrationsController < ApplicationController
  before_action :set_vendor_registration, only: %i[ show edit update destroy ]

  # GET /vendor_registrations or /vendor_registrations.json
  def index
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

      @vendor_registrations = base_scope.where(id: own_ids).or(base_scope.where(id: involved_ids)).distinct.order(created_at: :desc)
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
  end

  # GET /vendor_registrations/new
  def new
    @vendor_registration = VendorRegistration.new
    load_form_collections
  end

  # GET /vendor_registrations/1/edit
  def edit
    load_form_collections
  end

  # POST /vendor_registrations or /vendor_registrations.json
  def create
    @vendor_registration = VendorRegistration.new(vendor_registration_params)
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
    respond_to do |format|
      if @vendor_registration.update(vendor_registration_params)
        format.html { redirect_to vendor_registrations_path, notice: "Vendor registration was successfully updated.", status: :see_other }
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
    @vendor_registration.destroy!

    respond_to do |format|
      format.html { redirect_to vendor_registrations_path, notice: "Vendor registration was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
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
        :stakeholder_category_id, :registration_type_id, :company_name, :firm_id, :vendor_name, :firm_type, :gst_no, :pan_no,
        :email, :mobile_no, :state_id, :district_id, :block_id, :pin_no, :contact_person_name,
        :contact_person_designation, :msme, :msme_number, :company_status, :business_description,
        theme_ids: [], product_ids: [], product_variety_ids: []
      )

      %i[theme_ids product_ids product_variety_ids].each do |association_key|
        permitted_params[association_key] = Array(permitted_params[association_key]).reject(&:blank?)
      end

      permitted_params
    end

    def load_form_collections
      @stakeholder_categories = StakeholderCategory.order(:name)
      @registration_types = RegistrationType.order(:name)
      @firms = Firm.order(:name)
      @states = State.order(:name)
      @districts = District.includes(:state).order(:name)
      @blocks = Block.includes(district: :state).order(:name)
      @themes = Theme.includes(products: :product_varieties).order(:name)
      @products = Product.includes(:theme).order(:name)
      @product_varieties = ProductVariety.includes(product: :theme).order(:name)
    end
end
