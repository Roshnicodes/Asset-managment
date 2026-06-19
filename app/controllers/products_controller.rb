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
    prepare_product_form_collections
  end

  def create
    @product = Product.new(product_params)

    if enforce_product_department!(@product) && @product.save
      redirect_to products_path, notice: "Product created successfully."
    else
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

  def product_params
    params.require(:product).permit(:name, :product_code, :description, :theme_id, :stakeholder_category_id)
  end

  def product_scope
    scope = Product.all
    return scope if admin_user?
    return scope.none if current_employee_master&.stakeholder_category_id.blank?

    stakeholder_id = current_employee_master.stakeholder_category_id
    scope.left_outer_joins(:theme).where(
      "products.stakeholder_category_id = :stakeholder_id OR themes.stakeholder_category_id = :stakeholder_id",
      stakeholder_id: stakeholder_id
    )
  end

  def prepare_product_form_collections
    @stakeholders = admin_user? ? StakeholderCategory.order(:name) : StakeholderCategory.where(id: current_employee_master&.stakeholder_category_id)
    @themes = if admin_user?
      Theme.order(:name)
    elsif current_employee_master&.stakeholder_category_id.present?
      Theme.where(stakeholder_category_id: current_employee_master.stakeholder_category_id).order(:name)
    else
      Theme.none
    end
  end

  def enforce_product_department!(product)
    return true if admin_user?

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

end
