class DistrictsController < ApplicationController

  def index
    districts = District.joins(:state).includes(:state).order(:code, :name)
    if search_query.present?
      districts = districts.where(
        "LOWER(districts.name) LIKE :query OR LOWER(districts.code) LIKE :query OR LOWER(states.name) LIKE :query OR LOWER(states.code) LIKE :query",
        query: search_pattern
      )
    end

    @districts, @pagination = paginate_scope(districts)
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
    params.require(:district).permit(:code, :name, :state_id)
  end

end
