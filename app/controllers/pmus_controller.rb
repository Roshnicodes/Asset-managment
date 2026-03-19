class PmusController < ApplicationController

  def index
    @pmus = Pmu.all
  end

  def new
    @pmu = Pmu.new
    @districts = District.all
  end

  def create
    @pmu = Pmu.new(pmu_params)

    if @pmu.save
      redirect_to pmus_path
    else
      render :new
    end
  end

  def edit
    @pmu = Pmu.find(params[:id])
    @districts = District.all
  end

  def update
    @pmu = Pmu.find(params[:id])

    if @pmu.update(pmu_params)
      redirect_to pmus_path
    else
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
    params.require(:pmu).permit(:name, :district_id)
  end

end