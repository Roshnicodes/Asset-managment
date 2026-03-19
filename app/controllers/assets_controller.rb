class AssetsController < ApplicationController

  def index
    @assets = Asset.all
  end

  def new
    @asset = Asset.new
    @products = Product.all
  end

  def create
    @asset = Asset.new(asset_params)

    if @asset.save
      redirect_to assets_path
    else
      render :new
    end
  end

  def edit
    @asset = Asset.find(params[:id])
    @products = Product.all
  end

  def update
    @asset = Asset.find(params[:id])

    if @asset.update(asset_params)
      redirect_to assets_path
    else
      render :edit
    end
  end

  def destroy
    Asset.find(params[:id]).destroy
    redirect_to assets_path
  end

  private

  def asset_params
    params.require(:asset).permit(:name, :product_id, :serial_number)
  end

end