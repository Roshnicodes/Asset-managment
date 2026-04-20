class AddReceivedQuantityToQuotationProposalVendorItems < ActiveRecord::Migration[7.1]
  def change
    add_column :quotation_proposal_vendor_items, :received_quantity, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column :quotation_proposal_vendor_items, :last_goods_received_at, :datetime
  end
end
