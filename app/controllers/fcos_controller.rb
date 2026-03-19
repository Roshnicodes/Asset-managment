class FcosController < ApplicationController

  def index
    @fcos = Fco.all
  end

  def new
    @fco = Fco.new
    @pmus = Pmu.all
  end

  def create
    @fco = Fco.new(fco_params)

    if @fco.save
      redirect_to fcos_path
    else
      render :new
    end
  end

  def edit
    @fco = Fco.find(params[:id])
    @pmus = Pmu.all
  end

  def update
    @fco = Fco.find(params[:id])

    if @fco.update(fco_params)
      redirect_to fcos_path
    else
      render :edit
    end
  end

 def destroy
  @fco = Fco.find(params[:id])

  if @fco.destroy
    redirect_to fcos_path, notice: "Deleted successfully"
  else
    redirect_to fcos_path, alert: "Cannot delete. Tos exist."
  end
end

  private

  def fco_params
    params.require(:fco).permit(:name, :pmu_id)
  end

end