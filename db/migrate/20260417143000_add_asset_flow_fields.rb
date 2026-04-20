class AddAssetFlowFields < ActiveRecord::Migration[8.1]
  def change
    change_table :assets, bulk: true do |t|
      t.string :asset_code
      t.string :unique_product_code
      t.references :quotation_proposal_vendor_invoice_request, foreign_key: true, index: { name: "idx_assets_on_invoice_request" }
      t.references :quotation_proposal_vendor_item, foreign_key: true, index: { name: "idx_assets_on_vendor_item" }
    end

    add_index :assets, :asset_code, unique: true
    add_index :assets, :unique_product_code, unique: true

    add_column :quotation_proposal_vendor_invoice_requests, :assets_created_at, :datetime
  end
end
