class AssetInsurancesController < ApplicationController
  before_action :ensure_asset_schema_loaded
  before_action :set_asset, only: %i[edit update destroy]
  before_action :ensure_admin_asset_insurance_management!, only: %i[edit update destroy]

  def index
    load_insurance_page_data
  end

  def overview
    @assets = insurance_asset_scope.serial_number_ascending
  end

  def edit
  end

  def update
    if @asset.update(asset_insurance_attributes(asset_insurance_params))
      redirect_to asset_insurances_path(asset_ids: @asset.id), notice: "Insurance details updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @asset.update_columns(
      insured: nil,
      insurance_date: nil,
      insurance_company_name: nil,
      insurance_policy_number: nil,
      insurance_expiry_date: nil,
      updated_at: Time.current
    )

    redirect_to asset_insurances_path(asset_ids: @asset.id), notice: "Insurance details deleted successfully."
  end

  def update_all
    @asset_ids_filter = normalized_asset_ids.join(",")
    @assets = insurance_asset_scope.serial_number_ascending
    @workspace_assets = build_workspace_assets_for_update

    if using_bulk_insurance_update? && selected_asset_ids.blank?
      redirect_to asset_insurances_path(asset_ids: @asset_ids_filter.presence), alert: "Please select at least one asset."
      return
    end

    if using_bulk_insurance_update? && bulk_insurance_params[:insured].blank?
      redirect_to asset_insurances_path(asset_ids: @asset_ids_filter.presence), alert: "Please choose an insurance status."
      return
    end

    Asset.transaction do
      @workspace_assets.each(&:save!)
    end

    redirect_to asset_insurances_path(asset_ids: @asset_ids_filter.presence), notice: "Insurance details saved successfully."
  rescue ActiveRecord::RecordInvalid
    flash.now[:alert] = "Please complete insurance company, policy number, insurance date, and expiry date for every asset marked Yes."
    render :index, status: :unprocessable_entity
  end

  private

  def set_asset
    @asset = insurance_asset_scope.find(params[:id])
  end

  def ensure_admin_asset_insurance_management!
    return if admin_user?

    redirect_to asset_insurances_path, alert: "Only admin can edit or delete asset insurance details."
  end

  def load_insurance_page_data
    @asset_ids_filter = normalized_asset_ids.join(",")
    @assets = insurance_asset_scope.serial_number_ascending
    @workspace_assets =
      if normalized_asset_ids.any?
        ordered_assets(insurance_asset_scope.where(id: normalized_asset_ids).to_a, normalized_asset_ids)
      else
        insurance_asset_scope.where(insured: nil).serial_number_ascending.to_a
      end
  end

  def build_workspace_assets_for_update
    if using_bulk_insurance_update?
      assets = insurance_asset_scope.where(id: selected_asset_ids).to_a
      assets.each do |asset|
        asset.assign_attributes(asset_insurance_attributes(bulk_insurance_params))
      end

      return ordered_assets(assets, selected_asset_ids)
    end

    submitted_rows = asset_insurance_rows
    submitted_ids = submitted_rows.keys.map(&:to_i)
    assets = insurance_asset_scope.where(id: submitted_ids).to_a

    assets.each do |asset|
      asset.assign_attributes(asset_insurance_attributes(submitted_rows[asset.id.to_s] || {}))
    end

    ordered_assets(assets, normalized_asset_ids.presence || submitted_ids)
  end

  def insurance_asset_scope
    Asset.includes(:product, :stakeholder_category, :primary_office_category, :secondary_office_category, :quotation_proposal_vendor_item)
  end

  def ordered_assets(assets, ids)
    indexed_assets = assets.index_by(&:id)
    ids.filter_map { |id| indexed_assets[id.to_i] }
  end

  def normalized_asset_ids
    @normalized_asset_ids ||= params[:asset_ids].to_s.split(",").filter_map do |value|
      cleaned_value = value.to_s.strip
      next if cleaned_value.blank?

      Integer(cleaned_value, exception: false)
    end.uniq
  end

  def asset_insurance_rows
    params.fetch(:assets, {}).to_unsafe_h
  end

  def using_bulk_insurance_update?
    params[:bulk_insurance_update].present?
  end

  def selected_asset_ids
    @selected_asset_ids ||= Array(params[:selected_asset_ids]).filter_map do |value|
      Integer(value, exception: false)
    end.uniq
  end

  def bulk_insurance_params
    @bulk_insurance_params ||= params.permit(
      :insured,
      :insurance_date,
      :insurance_company_name,
      :insurance_policy_number,
      :insurance_expiry_date
    )
  end

  def asset_insurance_params
    params.require(:asset).permit(
      :insured,
      :insurance_date,
      :insurance_company_name,
      :insurance_policy_number,
      :insurance_expiry_date
    )
  end

  def asset_insurance_attributes(raw_attributes)
    attribute_params =
      if raw_attributes.is_a?(ActionController::Parameters)
        raw_attributes
      else
        ActionController::Parameters.new(raw_attributes)
      end

    permitted_attributes = attribute_params.permit(
      :insured,
      :insurance_date,
      :insurance_company_name,
      :insurance_policy_number,
      :insurance_expiry_date
    )

    {
      insured: parse_insured_value(permitted_attributes[:insured]),
      insurance_date: permitted_attributes[:insurance_date],
      insurance_company_name: permitted_attributes[:insurance_company_name],
      insurance_policy_number: permitted_attributes[:insurance_policy_number],
      insurance_expiry_date: permitted_attributes[:insurance_expiry_date]
    }
  end

  def parse_insured_value(value)
    return nil if value.blank?

    ActiveModel::Type::Boolean.new.cast(value)
  end

  def ensure_asset_schema_loaded
    Asset.ensure_structured_code_columns_loaded!
  end
end
