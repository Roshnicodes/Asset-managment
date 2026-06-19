class StatesController < ApplicationController

  def index
    states = State.order(:code, :name)
    if search_query.present?
      states = states.where(
        "LOWER(states.name) LIKE :query OR LOWER(states.code) LIKE :query",
        query: search_pattern
      )
    end

    @states, @pagination = paginate_scope(states)
  end

  def show
    redirect_to states_path
  end

  def new
    @state = State.new
  end

  def create
    @state = State.new(state_params)

    if @state.save
      redirect_to states_path
    else
      render :new
    end
  end

  def edit
    @state = State.find(params[:id])
  end

  def update
    @state = State.find(params[:id])

    if @state.update(state_params)
      redirect_to states_path
    else
      render :edit
    end
  end

def destroy
  @state = State.find(params[:id])

  if @state.destroy
    redirect_to states_path, notice: "Deleted successfully"
  else
    redirect_to states_path, alert: "Cannot delete. Districts exist."
  end
end

  private

  def state_params
    params.require(:state).permit(:code, :name)
  end

end
