class PmusController < ApplicationController

  def index
    @pmus = Pmu.includes(:block, district: :state).order(:name)
  end

  def new
    @pmu = Pmu.new
    @blocks = Block.includes(district: :state).order(:name)
  end

  def create
    @pmu = Pmu.new(pmu_params)
    assign_district_from_block(@pmu)

    if @pmu.save
      redirect_to pmus_path
    else
      @blocks = Block.includes(district: :state).order(:name)
      render :new
    end
  end

  def edit
    @pmu = Pmu.find(params[:id])
    @blocks = Block.includes(district: :state).order(:name)
  end

  def update
    @pmu = Pmu.find(params[:id])
    @pmu.assign_attributes(pmu_params)
    assign_district_from_block(@pmu)

    if @pmu.save
      redirect_to pmus_path
    else
      @blocks = Block.includes(district: :state).order(:name)
      render :edit
    end
  end

#   def destroy
#     Pmu.find(params[:id]).destroy
#     redirect_to pmus_path
#   end
def destroy
  @pmu = Pmu.find(params[:id])

  if @pmu.destroy
    redirect_to pmus_path, notice: "Deleted successfully"
  else
    redirect_to pmus_path, alert: "Cannot delete. Fcos exist."
  end
end

  private

  def pmu_params
    params.require(:pmu).permit(:name, :district_id, :block_id)
  end

  def assign_district_from_block(pmu)
    return unless pmu.block

    pmu.district = pmu.block.district
  end

end
