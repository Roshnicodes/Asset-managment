class AddGoodsReceiveFieldsToQuotationProposalVendorItems < ActiveRecord::Migration[7.1]
  def change
    change_table :quotation_proposal_vendor_items, bulk: true do |t|
      t.boolean :goods_received
      t.boolean :fixed_asset
    end
  end
end
