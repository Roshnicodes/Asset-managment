class VendorRegistrationsController < ApplicationController
  before_action :set_vendor_registration, only: %i[ show edit update destroy ]

  # GET /vendor_registrations or /vendor_registrations.json
  def index
    @vendor_registrations = VendorRegistration.includes(:stakeholder_category, :registration_type, :firm, :state, :district, :block).order(created_at: :desc)
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
