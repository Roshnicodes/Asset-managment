class VendorBankMastersController < ApplicationController
  before_action :set_vendor_bank_master, only: %i[ show edit update destroy ]

  # GET /vendor_bank_masters or /vendor_bank_masters.json
  def index
    @vendor_bank_masters = VendorBankMaster.masters
  end

  # GET /vendor_bank_masters/1 or /vendor_bank_masters/1.json
  def show
  end

  # GET /vendor_bank_masters/new
  def new
    @vendor_bank_master = VendorBankMaster.new
  end

  # GET /vendor_bank_masters/1/edit
  def edit
  end

  # POST /vendor_bank_masters or /vendor_bank_masters.json
  def create
    @vendor_bank_master = VendorBankMaster.new(vendor_bank_master_params)

    respond_to do |format|
      if @vendor_bank_master.save
        format.html { redirect_to vendor_bank_masters_path, notice: "Vendor bank master was successfully created." }
        format.json { render :show, status: :created, location: @vendor_bank_master }
      else
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
      params.expect(vendor_bank_master: [ :bank_name ])
    end
end
