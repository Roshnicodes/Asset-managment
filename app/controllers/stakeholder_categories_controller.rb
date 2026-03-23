class StakeholderCategoriesController < ApplicationController
  before_action :set_stakeholder_category, only: %i[ show edit update destroy ]

  # GET /stakeholder_categories or /stakeholder_categories.json
  def index
    @stakeholder_categories = StakeholderCategory.includes(:office_category, logo_file_attachment: :blob).order(:name)
  end

  # GET /stakeholder_categories/1 or /stakeholder_categories/1.json
  def show
    redirect_to stakeholder_categories_path
  end

  # GET /stakeholder_categories/new
  def new
    @stakeholder_category = StakeholderCategory.new
    load_office_categories
  end

  # GET /stakeholder_categories/1/edit
  def edit
    load_office_categories
  end

  # POST /stakeholder_categories or /stakeholder_categories.json
  def create
    @stakeholder_category = StakeholderCategory.new(stakeholder_category_params)

    respond_to do |format|
      if @stakeholder_category.save
        format.html { redirect_to stakeholder_categories_path, notice: "Stakeholder category was successfully created." }
        format.json { render :show, status: :created, location: @stakeholder_category }
      else
        load_office_categories
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @stakeholder_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /stakeholder_categories/1 or /stakeholder_categories/1.json
  def update
    respond_to do |format|
      if @stakeholder_category.update(stakeholder_category_params)
        format.html { redirect_to stakeholder_categories_path, notice: "Stakeholder category was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @stakeholder_category }
      else
        load_office_categories
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @stakeholder_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /stakeholder_categories/1 or /stakeholder_categories/1.json
  def destroy
    @stakeholder_category.destroy!

    respond_to do |format|
      format.html { redirect_to stakeholder_categories_path, notice: "Stakeholder category was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_stakeholder_category
      @stakeholder_category = StakeholderCategory.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def stakeholder_category_params
      params.expect(stakeholder_category: [ :name, :office_category_id, :address, :logo_url, :logo_file, :contact_no, :email_id ])
    end

    def load_office_categories
      @office_categories = OfficeCategory.order(:name)
    end
end
