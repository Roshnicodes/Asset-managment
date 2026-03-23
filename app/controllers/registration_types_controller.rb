class RegistrationTypesController < ApplicationController
  before_action :set_registration_type, only: %i[ edit update destroy ]

  # GET /registration_types or /registration_types.json
  def index
    @registration_types = RegistrationType.all
  end

  # GET /registration_types/new
  def new
    @registration_type = RegistrationType.new
  end

  # GET /registration_types/1/edit
  def edit
  end

  # POST /registration_types or /registration_types.json
  def create
    @registration_type = RegistrationType.new(registration_type_params)

    respond_to do |format|
      if @registration_type.save
        format.html { redirect_to registration_types_path, notice: "Registration type was successfully created." }
        format.json { render :show, status: :created, location: @registration_type }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @registration_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /registration_types/1 or /registration_types/1.json
  def update
    respond_to do |format|
      if @registration_type.update(registration_type_params)
        format.html { redirect_to registration_types_path, notice: "Registration type was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @registration_type }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @registration_type.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /registration_types/1 or /registration_types/1.json
  def destroy
    @registration_type.destroy!

    respond_to do |format|
      format.html { redirect_to registration_types_path, notice: "Registration type was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_registration_type
      @registration_type = RegistrationType.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def registration_type_params
      params.expect(registration_type: [ :name, :stakeholder_category_id ])
    end
end
