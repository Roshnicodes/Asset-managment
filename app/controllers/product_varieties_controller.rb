class ProductVarietiesController < ApplicationController
  before_action :set_product_variety, only: %i[ show edit update destroy ]

  # GET /product_varieties or /product_varieties.json
  def index
    @product_varieties = product_variety_scope.includes(product: :theme).order(:name)
  end

  # GET /product_varieties/1 or /product_varieties/1.json
  def show
  end

  # GET /product_varieties/new
  def new
    @product_variety = ProductVariety.new
    load_themes
  end

  # GET /product_varieties/1/edit
  def edit
    load_themes
  end

  # POST /product_varieties or /product_varieties.json
  def create
    @product_variety = ProductVariety.new(product_variety_params)

    respond_to do |format|
      if enforce_product_variety_department!(@product_variety) && @product_variety.save
        format.html { redirect_to product_varieties_path, notice: "Product type was successfully created." }
        format.json { render :show, status: :created, location: @product_variety }
      else
        load_themes
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product_variety.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /product_varieties/1 or /product_varieties/1.json
  def update
    @product_variety.assign_attributes(product_variety_params)

    respond_to do |format|
      if enforce_product_variety_department!(@product_variety) && @product_variety.save
        format.html { redirect_to product_varieties_path, notice: "Product type was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @product_variety }
      else
        load_themes
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product_variety.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /product_varieties/1 or /product_varieties/1.json
  def destroy
    @product_variety.destroy!

    respond_to do |format|
      format.html { redirect_to product_varieties_path, notice: "Product type was successfully deleted.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product_variety
      @product_variety = product_variety_scope.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def product_variety_params
      params.expect(product_variety: [ :name, :product_type_code, :product_id, :stakeholder_category_id ])
    end

    def load_themes
      stakeholder_id = current_employee_master&.stakeholder_category_id

      @stakeholders = if global_product_catalog_admin?
        StakeholderCategory.order(:name)
      elsif stakeholder_id.present?
        StakeholderCategory.where(id: stakeholder_id)
      else
        StakeholderCategory.none
      end

      @themes = if global_product_catalog_admin?
        Theme.includes(:products).order(:name)
      elsif stakeholder_id.present?
        Theme
          .where(stakeholder_category_id: stakeholder_id)
          .includes(:products)
          .order(:name)
      else
        Theme.none
      end
    end

    def product_variety_scope
      scope = ProductVariety.all
      return scope if global_product_catalog_admin?

      stakeholder_id = current_employee_master&.stakeholder_category_id
      return scope.none if stakeholder_id.blank?

      scope.joins(product: :theme).where(
        "product_varieties.stakeholder_category_id = :stakeholder_id OR products.stakeholder_category_id = :stakeholder_id OR themes.stakeholder_category_id = :stakeholder_id",
        stakeholder_id: stakeholder_id
      )
    end

    def enforce_product_variety_department!(product_variety)
      return true if global_product_catalog_admin?

      stakeholder = current_employee_master&.stakeholder_category
      if stakeholder.blank?
        product_variety.errors.add(:base, "Employee department is not mapped.")
        return false
      end

      product_variety.stakeholder_category = stakeholder
      return true if product_variety.product_id.blank? ||
        Product.left_outer_joins(:theme).where(id: product_variety.product_id).where(
          "products.stakeholder_category_id = :stakeholder_id OR themes.stakeholder_category_id = :stakeholder_id",
          stakeholder_id: stakeholder.id
        ).exists?

      product_variety.errors.add(:product_id, "must belong to your department")
      false
    end

    def global_product_catalog_admin?
      admin_user? && current_employee_master&.stakeholder_category_id.blank?
    end
end
