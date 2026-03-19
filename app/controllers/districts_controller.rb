class DistrictsController < ApplicationController

  def index
    @districts = District.all
  end

  def new
    @district = District.new
    @states = State.all
  end

  def create
    @district = District.new(district_params)

    if @district.save
      redirect_to districts_path
    else
      render :new
    end
  end

  def edit
    @district = District.find(params[:id])
    @states = State.all
  end

  def update
    @district = District.find(params[:id])

    if @district.update(district_params)
      redirect_to districts_path
    else
      render :edit
    end
  end

#   def destroy
#     District.find(params[:id]).destroy
#     redirect_to districts_path
#   end

def destroy
  @district = District.find(params[:id])

  if @district.destroy
    redirect_to districts_path, notice: "Deleted successfully"
  else
    redirect_to districts_path, alert: "Cannot delete. PMUS exist."
  end
end

  private

  def district_params
    params.require(:district).permit(:name,:state_id)
  end

end