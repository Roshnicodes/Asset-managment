class AssetsController < ApplicationController

  def index
    @rate_filter = params[:rate_filter].to_s
    @assets = Asset.includes(:product, :quotation_proposal_vendor_item)
    @assets = apply_rate_filter(@assets)
    @assets = @assets.recent_first
    load_invoice_request_asset_workspace
  end

  def new
    @asset = Asset.new
    @products = Product.all
  end

  def create
    @asset = Asset.new(asset_params)

    if @asset.save
      redirect_to assets_path
    else
      render :new
    end
  end

  def edit
    @asset = Asset.find(params[:id])
    @products = Product.all
  end

  def update
    @asset = Asset.find(params[:id])

    if @asset.update(asset_params)
      redirect_to assets_path
    else
      render :edit
    end
  end

  def destroy
    asset = Asset.find(params[:id])

    if asset.destroy
      redirect_to assets_path, notice: "Asset deleted successfully."
    else
      redirect_to assets_path, alert: asset.errors.full_messages.to_sentence.presence || "Asset delete nahi ho paaya."
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
      redirect_to assets_path, alert: asset.errors.full_messages.to_sentence.presence || "Asset delete nahi ho paaya."
    end
  end

  private

  def asset_params
    params.require(:asset).permit(:name, :product_id, :serial_number, :unique_product_code)
  end

  def load_invoice_request_asset_workspace
    return unless params[:invoice_request_id].present?

    @asset_products = Product.order(:name)
    @asset_invoice_request = QuotationProposalVendorInvoiceRequest
      .includes(
        :assets,
        quotation_proposal_vendor: [
          :vendor_registration,
          { quotation_proposal: :committee_steps },
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

    invoice_request.snapshot_items.each do |item|
      vendor_item = invoice_request.quotation_proposal_vendor.vendor_items.find { |record| record.id == item[:vendor_item_id].to_i }
      next unless vendor_item

      suggested_product = Product.find_by(name: item[:item_name])
      quantity_count = [item[:received_quantity].to_d.to_i, 1].max

      quantity_count.times do |index|
        rows << {
          vendor_item_id: vendor_item.id,
          asset_name: item[:item_name],
          suggested_product_id: suggested_product&.id,
          unit_name: item[:unit_name],
          row_label: "#{item[:item_name]} ##{index + 1}",
          unique_product_code: nil
        }
      end
    end

    rows
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

end
