class ThemesController < ApplicationController

  def index
    @themes = Theme.order(:name)
  end

  def new
    @theme = Theme.new
  end

  def create
    @theme = Theme.new(theme_params)

    if @theme.save
      redirect_to themes_path, notice: "Vendor thematic type created successfully."
    else
      render :new
    end
  end

  def edit
    @theme = Theme.find(params[:id])
  end

  def update
    @theme = Theme.find(params[:id])

    if @theme.update(theme_params)
      redirect_to themes_path, notice: "Vendor thematic type updated successfully."
    else
      render :edit
    end
  end

  def destroy
    @theme = Theme.find(params[:id])
    @theme.destroy
    redirect_to themes_path, notice: "Vendor thematic type deleted successfully."
  end

  private
    
  def theme_params
    params.require(:theme).permit(:name)            
  end

end
