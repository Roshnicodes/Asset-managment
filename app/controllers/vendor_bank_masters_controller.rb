class VendorBankMastersController < ApplicationController
  before_action :set_vendor_bank_master, only: %i[ show edit update destroy ]

  # GET /vendor_bank_masters or /vendor_bank_masters.json
  def index
    @vendor_bank_masters = VendorBankMaster.includes(:vendor_registration).order(created_at: :desc)
  end

  # GET /vendor_bank_masters/1 or /vendor_bank_masters/1.json
  def show
  end

  # GET /vendor_bank_masters/new
  def new
    @vendor_bank_master = VendorBankMaster.new
    load_vendor_registrations
  end

  # GET /vendor_bank_masters/1/edit
  def edit
    load_vendor_registrations
  end

  # POST /vendor_bank_masters or /vendor_bank_masters.json
  def create
    @vendor_bank_master = VendorBankMaster.new(vendor_bank_master_params)

    respond_to do |format|
      if @vendor_bank_master.save
        format.html { redirect_to vendor_bank_masters_path, notice: "Vendor bank master was successfully created." }
        format.json { render :show, status: :created, location: @vendor_bank_master }
      else
        load_vendor_registrations
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @vendor_bank_master.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /vendor_bank_masters/1 or /vendor_bank_masters/1.json
  def update
    respond_to do |format|
      if @vendor_bank_master.update(vendor_bank_master_params)
        format.html { redirect_to vendor_bank_masters_path, notice: "Vendor bank master was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @vendor_bank_master }
      else
        load_vendor_registrations
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @vendor_bank_master.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /vendor_bank_masters/1 or /vendor_bank_masters/1.json
  def destroy
    @vendor_bank_master.destroy!

    respond_to do |format|
      format.html { redirect_to vendor_bank_masters_path, notice: "Vendor bank master was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_vendor_bank_master
      @vendor_bank_master = VendorBankMaster.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def vendor_bank_master_params
      params.expect(vendor_bank_master: [ :vendor_registration_id, :bank_name, :bank_address, :ifsc_code, :account_number, :account_type ])
    end

    def load_vendor_registrations
      @vendor_registrations = VendorRegistration.order(:vendor_name)
    end
end
