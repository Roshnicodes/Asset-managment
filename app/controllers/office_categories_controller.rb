class OfficeCategoriesController < ApplicationController
  before_action :set_office_category, only: %i[ show edit update destroy ]

  # GET /office_categories or /office_categories.json
  def index
    @office_categories = OfficeCategory.includes(:parent).order(:office_level, :name)
  end

  # GET /office_categories/1 or /office_categories/1.json
  def show
  end

  # GET /office_categories/new
  def new
    @office_category = OfficeCategory.new
    load_parent_categories
  end

  # GET /office_categories/1/edit
  def edit
    load_parent_categories
  end

  # POST /office_categories or /office_categories.json
  def create
    @office_category = OfficeCategory.new(office_category_params)

    respond_to do |format|
      if @office_category.save
        format.html { redirect_to office_categories_path, notice: "Office category was successfully created." }
        format.json { render :show, status: :created, location: @office_category }
      else
        load_parent_categories
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /office_categories/1 or /office_categories/1.json
  def update
    respond_to do |format|
      if @office_category.update(office_category_params)
        format.html { redirect_to office_categories_path, notice: "Office category was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @office_category }
      else
        load_parent_categories
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /office_categories/1 or /office_categories/1.json
  def destroy
    @office_category.destroy!

    respond_to do |format|
      format.html { redirect_to office_categories_path, notice: "Office category was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_office_category
      @office_category = OfficeCategory.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def office_category_params
      params.expect(office_category: [ :name, :office_level, :parent_id ])
    end

    def load_parent_categories
      @parent_categories = OfficeCategory.order(:name)
    end
end
