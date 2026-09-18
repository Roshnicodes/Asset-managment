class VendorSelectionCriteriaController < ApplicationController
  before_action :set_vendor_selection_criterion, only: %i[edit update destroy]
  before_action :load_themes, only: %i[new create edit update]

  def index
    @vendor_selection_criteria = VendorSelectionCriterion.includes(:theme).joins(:theme).order("themes.name ASC, vendor_selection_criteria.created_at DESC")
  end

  def new
    @vendor_selection_criterion = VendorSelectionCriterion.new
    @vendor_selection_criteria = [@vendor_selection_criterion]
    @vendor_selection_criteria_batch_context = default_vendor_selection_criteria_batch_context
  end

  def create
    if params[:vendor_selection_criteria].present?
      create_batch
      return
    end

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

  def create_batch
    @vendor_selection_criteria = vendor_selection_criteria_batch_params.reject { |attributes| blank_vendor_selection_criteria_row?(attributes) }.map do |attributes|
      VendorSelectionCriterion.new(attributes)
    end

    if @vendor_selection_criteria.blank?
      @vendor_selection_criterion = VendorSelectionCriterion.new
      @vendor_selection_criterion.errors.add(:base, "Please add at least one criteria.")
      @vendor_selection_criteria = [@vendor_selection_criterion]
      @vendor_selection_criteria_batch_context = vendor_selection_criteria_batch_context_params
      render :new, status: :unprocessable_entity
      return
    end

    created_count = 0

    ActiveRecord::Base.transaction do
      @vendor_selection_criteria.each do |vendor_selection_criterion|
        unless vendor_selection_criterion.save
          raise ActiveRecord::Rollback
        end

        created_count += 1
      end
    end

    if created_count == @vendor_selection_criteria.size
      redirect_to vendor_selection_criteria_path, notice: "#{created_count} #{'vendor selection criteria'.pluralize(created_count)} created successfully."
    else
      @vendor_selection_criterion = @vendor_selection_criteria.find { |vendor_selection_criterion| vendor_selection_criterion.errors.any? } || @vendor_selection_criteria.first
      @vendor_selection_criteria_batch_context = vendor_selection_criteria_batch_context_params
      render :new, status: :unprocessable_entity
    end
  end

  def set_vendor_selection_criterion
    @vendor_selection_criterion = VendorSelectionCriterion.find(params[:id])
  end

  def load_themes
    @themes = Theme.order(:name)
  end

  def vendor_selection_criterion_params
    params.require(:vendor_selection_criterion).permit(:theme_id, :criteria)
  end

  def vendor_selection_criteria_batch_params
    batch_context = vendor_selection_criteria_batch_context_params.to_h.compact_blank
    raw_rows = params.fetch(:vendor_selection_criteria, {})
    rows = if raw_rows.respond_to?(:to_unsafe_h)
      raw_rows.to_unsafe_h.sort_by { |index, _attributes| index.to_s.to_i }.map(&:last)
    else
      Array(raw_rows)
    end

    rows.map do |attributes|
      ActionController::Parameters.new(attributes)
        .permit(:criteria, :theme_id)
        .merge(batch_context)
    end
  end

  def vendor_selection_criteria_batch_context_params
    return default_vendor_selection_criteria_batch_context unless params[:vendor_selection_criteria_batch].present?

    params.require(:vendor_selection_criteria_batch).permit(:theme_id)
  end

  def default_vendor_selection_criteria_batch_context
    ActionController::Parameters.new.permit(:theme_id)
  end

  def blank_vendor_selection_criteria_row?(attributes)
    attributes[:criteria].to_s.strip.blank?
  end
end
