class UnitsController < ApplicationController
  before_action :set_unit, only: %i[ edit update destroy ]

  # GET /units or /units.json
  def index
    @units = Unit.all
  end

  # GET /units/new
  def new
    @unit = Unit.new
  end

  # GET /units/1/edit
  def edit
  end

  # POST /units or /units.json
  def create
    @unit = Unit.new(unit_params)

    respond_to do |format|
      if @unit.save
        format.html { redirect_to units_path, notice: "Unit was successfully created." }
        format.json { render :show, status: :created, location: @unit }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /units/1 or /units/1.json
  def update
    respond_to do |format|
      if @unit.update(unit_params)
        format.html { redirect_to units_path, notice: "Unit was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @unit }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @unit.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /units/1 or /units/1.json
  def destroy
    respond_to do |format|
      if @unit.destroy
        format.html { redirect_to units_path, notice: "Unit was successfully destroyed.", status: :see_other }
        format.json { head :no_content }
      else
        error_message = @unit.errors.full_messages.to_sentence.presence || "Unit could not be deleted."
        format.html { redirect_to units_path, alert: error_message, status: :see_other }
        format.json { render json: { error: error_message }, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_unit
      @unit = Unit.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def unit_params
      params.expect(unit: [ :name, :stakeholder_category_id ])
    end
end
