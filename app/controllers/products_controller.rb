class ProductsController < ApplicationController

  def index
    @products = Product.includes(:theme).order(:name)
  end

  def new
    @product = Product.new
    @themes = Theme.order(:name)
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to products_path, notice: "Product created successfully."
    else
      render :new
    end
  end

  def edit
    @product = Product.find(params[:id])
    @themes = Theme.order(:name)
  end

  def update
    @product = Product.find(params[:id])

    if @product.update(product_params)
      redirect_to products_path, notice: "Product updated successfully."
    else
      render :edit
    end
  end

  def destroy
    Product.find(params[:id]).destroy
    redirect_to products_path, notice: "Product deleted successfully."
  end

  private

  def product_params
    params.require(:product).permit(:name, :description, :theme_id)
  end

end
