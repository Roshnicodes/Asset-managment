class VendorSelectionCriteriaController < ApplicationController
  before_action :set_vendor_selection_criterion, only: %i[edit update destroy]
  before_action :load_themes, only: %i[new create edit update]

  def index
    @vendor_selection_criteria = VendorSelectionCriterion.includes(:theme).joins(:theme).order("themes.name ASC, vendor_selection_criteria.created_at DESC")
  end

  def new
    @vendor_selection_criterion = VendorSelectionCriterion.new
  end

  def create
    @vendor_selection_criterion = VendorSelectionCriterion.new(vendor_selection_criterion_params)

    if @vendor_selection_criterion.save
      redirect_to vendor_selection_criteria_path, notice: "Vendor selection criteria created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @vendor_selection_criterion.update(vendor_selection_criterion_params)
      redirect_to vendor_selection_criteria_path, notice: "Vendor selection criteria updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @vendor_selection_criterion.destroy
      redirect_to vendor_selection_criteria_path, notice: "Vendor selection criteria deleted successfully."
    else
      message = @vendor_selection_criterion.errors.full_messages.to_sentence.presence || "Vendor selection criteria could not be deleted."
      redirect_to vendor_selection_criteria_path, alert: message
    end
  end

  private

  def set_vendor_selection_criterion
    @vendor_selection_criterion = VendorSelectionCriterion.find(params[:id])
  end

  def load_themes
    @themes = Theme.order(:name)
  end

  def vendor_selection_criterion_params
    params.require(:vendor_selection_criterion).permit(:theme_id, :criteria)
  end
end
