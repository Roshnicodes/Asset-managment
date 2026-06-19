class AssetsController < ApplicationController
  before_action :ensure_asset_schema_loaded, only: %i[index new create edit update]
  before_action :ensure_admin_asset_management!, only: %i[edit update destroy remove]

  def index
    @rate_filter = params[:rate_filter].to_s
    @assets = Asset.includes(:product, :quotation_proposal_vendor_item)
    @assets = apply_rate_filter(@assets)
    @assets = @assets.serial_number_ascending
    load_invoice_request_asset_workspace
  end

  def new
    @asset = Asset.new
    load_asset_form_collections
  end

  def create
    @asset = Asset.new(asset_params)

    if @asset.save
      redirect_to asset_insurances_path(asset_ids: @asset.id), notice: "Asset saved successfully. Please capture insurance details."
    else
      load_asset_form_collections
      render :new
    end
  end

  def edit
    @asset = Asset.find(params[:id])
    load_asset_form_collections
  end

  def update
    @asset = Asset.find(params[:id])

    if @asset.update(asset_params)
      redirect_to assets_path
    else
      load_asset_form_collections
      render :edit
    end
  end

  def destroy
    asset = Asset.find(params[:id])

    if asset.destroy
      redirect_to assets_path, notice: "Asset deleted successfully."
    else
      redirect_to assets_path, alert: asset.errors.full_messages.to_sentence.presence || "Asset could not be deleted."
    end
  end

  def remove
    asset = Asset.find_by(id: params[:id])

    unless asset
      redirect_to assets_path, alert: "Asset was already deleted or could not be found."
      return
    end

    if asset.destroy
      redirect_to assets_path, notice: "Asset deleted successfully."
    else
      redirect_to assets_path, alert: asset.errors.full_messages.to_sentence.presence || "Asset could not be deleted."
    end
  end

  private

  def ensure_admin_asset_management!
    return if admin_user?

    redirect_to assets_path, alert: "Only admin can edit or delete assets."
  end

  def asset_params
    params.require(:asset).permit(
      :name,
      :product_id,
      :serial_number,
      :unique_product_code,
      :stakeholder_category_id,
      :primary_office_category_id,
      :secondary_office_category_id,
      :asset_code_date
    )
  end

  def load_invoice_request_asset_workspace
    return unless params[:invoice_request_id].present?

    @asset_products = Product.includes(:product_varieties).order(:name)
    load_asset_form_collections
    @asset_invoice_request = QuotationProposalVendorInvoiceRequest
      .includes(
        :assets,
        quotation_proposal_vendor: [
          :vendor_registration,
          { quotation_proposal: { theme: :stakeholder_category } },
          { vendor_items: { quotation_proposal_item: :unit } }
        ]
      )
      .find_by(id: params[:invoice_request_id])

    return if @asset_invoice_request.blank?

    quotation_proposal = @asset_invoice_request.quotation_proposal_vendor.quotation_proposal
    unless current_user == quotation_proposal.user || quotation_proposal.committee_user?(current_user)
      @asset_invoice_request = nil
      return
    end

    unless @asset_invoice_request.accepted?
      @asset_invoice_request = nil
      return
    end

    @asset_rows = build_invoice_request_asset_rows(@asset_invoice_request)
  end

  def build_invoice_request_asset_rows(invoice_request)
    rows = []
    suggested_stakeholder_id =
      invoice_request.quotation_proposal_vendor.quotation_proposal.theme&.stakeholder_category_id ||
      invoice_request.quotation_proposal_vendor.vendor_registration&.stakeholder_category_id

    invoice_request.snapshot_items.each do |item|
      vendor_item = invoice_request.quotation_proposal_vendor.vendor_items.find { |record| record.id == item[:vendor_item_id].to_i }
      next unless invoice_item_fixed_asset?(item, vendor_item)

      suggested_product = Product.find_by(name: item[:item_name])
      quantity_count = [item[:received_quantity].to_d.to_i, 1].max

      quantity_count.times do |index|
        rows << {
          vendor_item_id: vendor_item.id,
          asset_name: item[:item_name],
          suggested_product_id: suggested_product&.id,
          stakeholder_category_id: suggested_stakeholder_id,
          primary_office_category_id: nil,
          secondary_office_category_id: nil,
          asset_code_date: nil,
          unit_name: item[:unit_name],
          row_label: "#{item[:item_name]} ##{index + 1}",
          unique_product_code: suggested_product&.product_code
        }
      end
    end

    rows
  end

  def invoice_item_fixed_asset?(item, vendor_item)
    return false unless vendor_item
    return vendor_item.fixed_asset == true unless item&.key?(:fixed_asset)

    ActiveModel::Type::Boolean.new.cast(item[:fixed_asset]) == true
  end

  def apply_rate_filter(scope)
    case @rate_filter
    when "above_5000"
      scope.joins(:quotation_proposal_vendor_item)
           .where("quotation_proposal_vendor_items.quoted_rate > ?", 5000)
    when "upto_5000"
      scope.joins(:quotation_proposal_vendor_item)
           .where("quotation_proposal_vendor_items.quoted_rate <= ?", 5000)
    else
      scope
    end
  end

  def load_asset_form_collections
    @products = Product.includes(:product_varieties).order(:name)
    @asset_product_code_map = @products.each_with_object({}) do |product, product_code_map|
      product_code_map[product.id.to_s] = product.product_code.to_s.strip
    end
    @asset_stakeholders = StakeholderCategory.order(:name)
    @asset_office_category_grouped_options =
      OfficeCategory.ordered.group_by(&:stakeholder_category).map do |stakeholder, offices|
        [stakeholder&.name.to_s.strip.presence || "Other", offices.map { |office| [office.asset_code_segment, office.id] }]
      end
  end

  def ensure_asset_schema_loaded
    Asset.ensure_structured_code_columns_loaded!
  end
end
