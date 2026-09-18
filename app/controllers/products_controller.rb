class ProductsController < ApplicationController

  def index
    @products = product_scope.includes(:theme).order(:name)
  end

  def show
    @product = product_scope.find(params[:id])
    redirect_to edit_product_path(@product)
  end

  def new
    @product = Product.new
    @products = [@product]
    @product_batch_context = default_product_batch_context
    prepare_product_form_collections
  end

  def create
    if params[:products].present?
      create_batch
      return
    end

    @product = Product.new(product_params)

    if enforce_product_department!(@product) && @product.save
      redirect_to products_path, notice: "Product created successfully."
    else
      @products = [@product]
      prepare_product_form_collections
      render :new
    end
  end

  def edit
    @product = product_scope.find(params[:id])
    prepare_product_form_collections
  end

  def update
    @product = product_scope.find(params[:id])
    @product.assign_attributes(product_params)

    if enforce_product_department!(@product) && @product.save
      redirect_to products_path, notice: "Product updated successfully."
    else
      prepare_product_form_collections
      render :edit
    end
  end

  def destroy
    @product = product_scope.find(params[:id])

    if @product.destroy
      redirect_to products_path, notice: "Product deleted successfully."
    else
      message = @product.errors.full_messages.to_sentence.presence || "This product could not be deleted."
      redirect_to products_path, alert: message
    end
  end

  private

  def create_batch
    @products = product_batch_params.reject { |attributes| blank_product_row?(attributes) }.map do |attributes|
      Product.new(attributes)
    end

    if @products.blank?
      @product = Product.new
      @product.errors.add(:base, "Please add at least one product.")
      @products = [@product]
      @product_batch_context = product_batch_context_params
      prepare_product_form_collections
      render :new
      return
    end

    created_count = 0

    ActiveRecord::Base.transaction do
      @products.each do |product|
        unless enforce_product_department!(product) && product.save
          raise ActiveRecord::Rollback
        end

        created_count += 1
      end
    end

    if created_count == @products.size
      redirect_to products_path, notice: "#{created_count} #{'product'.pluralize(created_count)} created successfully."
    else
      @product = @products.find { |product| product.errors.any? } || @products.first
      @product_batch_context = product_batch_context_params
      prepare_product_form_collections
      render :new
    end
  end

  def product_params
    params.require(:product).permit(:name, :product_code, :description, :theme_id, :stakeholder_category_id)
  end

  def product_batch_params
    batch_context = product_batch_context_params.to_h.compact_blank
    raw_rows = params.fetch(:products, {})
    rows = if raw_rows.respond_to?(:to_unsafe_h)
      raw_rows.to_unsafe_h.sort_by { |index, _attributes| index.to_s.to_i }.map(&:last)
    else
      Array(raw_rows)
    end

    rows.map do |attributes|
      ActionController::Parameters.new(attributes)
        .permit(:name, :product_code, :description, :theme_id, :stakeholder_category_id)
        .merge(batch_context)
    end
  end

  def product_batch_context_params
    return default_product_batch_context unless params[:product_batch].present?

    params.require(:product_batch).permit(:theme_id, :stakeholder_category_id)
  end

  def default_product_batch_context
    ActionController::Parameters.new(
      stakeholder_category_id: (current_employee_master&.stakeholder_category_id unless global_product_catalog_admin?)
    ).permit(:theme_id, :stakeholder_category_id)
  end

  def blank_product_row?(attributes)
    attributes.slice(:name, :product_code, :description).values.all? { |value| value.to_s.strip.blank? }
  end

  def product_scope
    scope = Product.all
    return scope if global_product_catalog_admin?

    stakeholder_id = current_employee_master&.stakeholder_category_id
    return scope.none if stakeholder_id.blank?

    scope.left_outer_joins(:theme).where(
      "products.stakeholder_category_id = :stakeholder_id OR themes.stakeholder_category_id = :stakeholder_id",
      stakeholder_id: stakeholder_id
    )
  end

  def prepare_product_form_collections
    stakeholder_id = current_employee_master&.stakeholder_category_id

    @stakeholders = if global_product_catalog_admin?
      StakeholderCategory.order(:name)
    elsif stakeholder_id.present?
      StakeholderCategory.where(id: stakeholder_id)
    else
      StakeholderCategory.none
    end

    @themes = if global_product_catalog_admin?
      Theme.order(:name)
    elsif stakeholder_id.present?
      Theme.where(stakeholder_category_id: stakeholder_id).order(:name)
    else
      Theme.none
    end
  end

  def enforce_product_department!(product)
    return true if global_product_catalog_admin?

    stakeholder = current_employee_master&.stakeholder_category
    if stakeholder.blank?
      product.errors.add(:base, "Employee department is not mapped.")
      return false
    end

    product.stakeholder_category = stakeholder
    return true if product.theme_id.blank? || Theme.where(id: product.theme_id, stakeholder_category_id: stakeholder.id).exists?

    product.errors.add(:theme_id, "must belong to your department")
    false
  end

  def global_product_catalog_admin?
    admin_user? && current_employee_master&.stakeholder_category_id.blank?
  end

end
