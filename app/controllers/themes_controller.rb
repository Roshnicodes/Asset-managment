class ThemesController < ApplicationController

  def index
    @themes = Theme.all
  end

  def new
    @theme = Theme.new
  end

  def create
    @theme = Theme.new(theme_params)

    if @theme.save
      redirect_to themes_path
    else
      render :new
    end
  end

    def destroy
    @theme = Theme.find(params[:id])
    @theme.destroy
    redirect_to themes_path, notice: "Theme deleted successfully"
    end

  private

  def theme_params
    params.require(:theme).permit(:name)
  end

end