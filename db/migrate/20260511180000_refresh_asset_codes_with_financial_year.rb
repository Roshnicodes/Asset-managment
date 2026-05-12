class RefreshAssetCodesWithFinancialYear < ActiveRecord::Migration[8.1]
  def up
    Asset.includes(:stakeholder_category, :primary_office_category, :secondary_office_category, product: :product_varieties).find_each do |asset|
      next if asset.stakeholder_category.blank?
      next if asset.primary_office_category.blank?
      next if asset.secondary_office_category.blank?
      next if asset.product.blank?
      next if asset.asset_code_date.blank?
      next if asset.unique_product_code.blank?

      refreshed_asset_code = Asset.generate_asset_code(
        stakeholder_name: asset.stakeholder_category.name,
        primary_location: asset.primary_office_category.asset_code_segment,
        secondary_location: asset.secondary_office_category.asset_code_segment,
        product_type_code: asset.product.asset_product_type_code_segment,
        item_number: asset.unique_product_code,
        code_date: asset.asset_code_date
      )

      asset.update_columns(asset_code: refreshed_asset_code)
    end
  end

  def down
    # Asset codes intentionally remain on the refreshed financial-year format.
  end
end
