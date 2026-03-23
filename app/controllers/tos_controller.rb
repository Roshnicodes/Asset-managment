class TosController < ApplicationController

  def index
    @tos = To.includes(fco: { pmu: { district: :state } }).order(:name)
  end

  def new
    @to = To.new
    @fcos = Fco.includes(pmu: [:block, { district: :state }]).order(:name)
  end

  def create
    @to = To.new(to_params)

    if @to.save
      redirect_to tos_path
    else
      render :new
    end
  end

  def edit
    @to = To.find(params[:id])
    @fcos = Fco.includes(pmu: [:block, { district: :state }]).order(:name)
  end

  def update
    @to = To.find(params[:id])

    if @to.update(to_params)
      redirect_to tos_path
    else
      render :edit
    end
  end

  def destroy
    To.find(params[:id]).destroy
    redirect_to tos_path
  end

  private

  def to_params
    params.require(:to).permit(:name, :fco_id)
  end

end
