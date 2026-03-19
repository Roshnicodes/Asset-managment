class ProductVarietiesController < ApplicationController
  before_action :set_product_variety, only: %i[ show edit update destroy ]

  # GET /product_varieties or /product_varieties.json
  def index
    @product_varieties = ProductVariety.includes(product: :theme).order(:name)
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
      if @product_variety.save
        format.html { redirect_to product_varieties_path, notice: "Product variety was successfully created." }
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
    respond_to do |format|
      if @product_variety.update(product_variety_params)
        format.html { redirect_to product_varieties_path, notice: "Product variety was successfully updated.", status: :see_other }
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
      format.html { redirect_to product_varieties_path, notice: "Product variety was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_product_variety
      @product_variety = ProductVariety.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def product_variety_params
      params.expect(product_variety: [ :name, :product_id ])
    end

    def load_themes
      @themes = Theme.includes(:products).order(:name)
    end
end
