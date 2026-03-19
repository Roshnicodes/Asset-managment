class AllocationsController < ApplicationController

  def index
    @allocations = Allocation.all
  end

  def new
    @allocation = Allocation.new
    @assets = Asset.all
    @tos = To.all
  end

  def create
    @allocation = Allocation.new(allocation_params)

    if @allocation.save
      redirect_to allocations_path
    else
      render :new
    end
  end

  def destroy
    Allocation.find(params[:id]).destroy
    redirect_to allocations_path
  end

  private

  def allocation_params
    params.require(:allocation).permit(:asset_id, :to_id, :allocated_at)
  end

end