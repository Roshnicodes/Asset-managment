class OfficeCategoriesController < ApplicationController
  before_action :set_office_category, only: %i[ show edit update destroy ]

  # GET /office_categories or /office_categories.json
  def index
    @office_categories = OfficeCategory.ordered
  end

  # GET /office_categories/1 or /office_categories/1.json
  def show
  end

  # GET /office_categories/new
  def new
    @office_category = OfficeCategory.new
    load_form_collections
  end

  # GET /office_categories/1/edit
  def edit
    load_form_collections
  end

  # POST /office_categories or /office_categories.json
  def create
    @office_category = OfficeCategory.new(office_category_params)

    respond_to do |format|
      if @office_category.save
        format.html { redirect_to office_categories_path, notice: "Office structure was successfully created." }
        format.json { render :show, status: :created, location: @office_category }
      else
        load_form_collections
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /office_categories/1 or /office_categories/1.json
  def update
    respond_to do |format|
      if @office_category.update(office_category_params)
        format.html { redirect_to office_categories_path, notice: "Office structure was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @office_category }
      else
        load_form_collections
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /office_categories/1 or /office_categories/1.json
  def destroy
    respond_to do |format|
      if @office_category.destroy
        format.html { redirect_to office_categories_path, notice: "Office structure was successfully deleted.", status: :see_other }
        format.json { head :no_content }
      else
        format.html do
          redirect_to office_categories_path,
                      alert: @office_category.errors.full_messages.to_sentence.presence || "Office structure could not be deleted.",
                      status: :see_other
        end
        format.json { render json: @office_category.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_office_category
      @office_category = OfficeCategory.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def office_category_params
      params.expect(office_category: [:name, :parent_id, :stakeholder_category_id, :office_category_master_id, :state_id, :district_id, :block_id])
    end

    def load_form_collections
      @stakeholders = StakeholderCategory.order(:name)
      @states = State.order(:name)
      @district_filter_data = District.includes(:state).order(:name).map do |district|
        { id: district.id, name: district.name, state_id: district.state_id }
      end
      @block_filter_data = Block.includes(district: :state).order(:name).map do |block|
        { id: block.id, name: block.name, district_id: block.district_id, state_id: block.district&.state_id }
      end

      category_master_scope = OfficeCategoryMaster.includes(:stakeholder_category).ordered
      if @office_category.stakeholder_category_id.present?
        category_master_scope = category_master_scope.where(stakeholder_category_id: @office_category.stakeholder_category_id)
      end
      @category_master_options = category_master_scope.map do |master|
        [master.name, master.id]
      end

      parent_scope = OfficeCategory.ordered
      parent_scope = parent_scope.where.not(id: @office_category.id) if @office_category.persisted?
      if @office_category.stakeholder_category_id.present?
        parent_scope = parent_scope.where(stakeholder_category_id: @office_category.stakeholder_category_id)
      end
      @parent_category_options = parent_scope.map do |category|
        [category.display_name, category.id]
      end
    end
end
