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
    @product_varieties = [@product_variety]
    @product_variety_batch_context = default_product_variety_batch_context
    load_themes
  end

  # GET /product_varieties/1/edit
  def edit
    load_themes
  end

  # POST /product_varieties or /product_varieties.json
  def create
    if params[:product_varieties].present?
      create_batch
      return
    end

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
    def create_batch
      @product_varieties = product_variety_batch_params.reject { |attributes| blank_product_variety_row?(attributes) }.map do |attributes|
        ProductVariety.new(attributes)
      end

      if @product_varieties.blank?
        @product_variety = ProductVariety.new
        @product_variety.errors.add(:base, "Please add at least one product type.")
        @product_varieties = [@product_variety]
        @product_variety_batch_context = product_variety_batch_context_params
        load_themes
        render :new, status: :unprocessable_entity
        return
      end

      created_count = 0

      ActiveRecord::Base.transaction do
        @product_varieties.each do |product_variety|
          unless enforce_product_variety_department!(product_variety) && product_variety.save
            raise ActiveRecord::Rollback
          end

          created_count += 1
        end
      end

      if created_count == @product_varieties.size
        redirect_to product_varieties_path, notice: "#{created_count} #{'product type'.pluralize(created_count)} were successfully created."
      else
        @product_variety = @product_varieties.find { |product_variety| product_variety.errors.any? } || @product_varieties.first
        @product_variety_batch_context = product_variety_batch_context_params
        load_themes
        render :new, status: :unprocessable_entity
      end
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_product_variety
      @product_variety = product_variety_scope.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def product_variety_params
      params.expect(product_variety: [ :name, :product_type_code, :product_id, :stakeholder_category_id ])
    end

    def product_variety_batch_params
      batch_context = product_variety_batch_context_params.to_h.compact_blank
      raw_rows = params.fetch(:product_varieties, {})
      rows = if raw_rows.respond_to?(:to_unsafe_h)
        raw_rows.to_unsafe_h.sort_by { |index, _attributes| index.to_s.to_i }.map(&:last)
      else
        Array(raw_rows)
      end

      rows.map do |attributes|
        ActionController::Parameters.new(attributes)
          .permit(:name, :product_type_code, :product_id, :stakeholder_category_id)
          .merge(batch_context)
      end
    end

    def product_variety_batch_context_params
      return default_product_variety_batch_context unless params[:product_variety_batch].present?

      params.require(:product_variety_batch).permit(:product_id, :stakeholder_category_id)
    end

    def default_product_variety_batch_context
      ActionController::Parameters.new(
        stakeholder_category_id: (current_employee_master&.stakeholder_category_id unless global_product_catalog_admin?)
      ).permit(:product_id, :stakeholder_category_id)
    end

    def blank_product_variety_row?(attributes)
      attributes.slice(:name, :product_type_code).values.all? { |value| value.to_s.strip.blank? }
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
