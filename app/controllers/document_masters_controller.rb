class DocumentMastersController < ApplicationController
  before_action :set_document_master, only: %i[ show edit update destroy ]

  # GET /document_masters or /document_masters.json
  def index
    @document_masters = DocumentMaster.all
  end

  # GET /document_masters/1 or /document_masters/1.json
  def show
  end

  # GET /document_masters/new
  def new
    @document_master = DocumentMaster.new
  end

  # GET /document_masters/1/edit
  def edit
  end

  # POST /document_masters or /document_masters.json
  def create
    @document_master = DocumentMaster.new(document_master_params)

    respond_to do |format|
      if @document_master.save
        format.html { redirect_to @document_master, notice: "Document master was successfully created." }
        format.json { render :show, status: :created, location: @document_master }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @document_master.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /document_masters/1 or /document_masters/1.json
  def update
    respond_to do |format|
      if @document_master.update(document_master_params)
        format.html { redirect_to @document_master, notice: "Document master was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @document_master }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @document_master.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /document_masters/1 or /document_masters/1.json
  def destroy
    @document_master.destroy!

    respond_to do |format|
      format.html { redirect_to document_masters_path, notice: "Document master was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_document_master
      @document_master = DocumentMaster.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def document_master_params
      params.expect(document_master: [ :name ])
    end
end
