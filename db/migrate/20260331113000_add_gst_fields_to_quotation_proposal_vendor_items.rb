class AddGstFieldsToQuotationProposalVendorItems < ActiveRecord::Migration[8.1]
  def change
    add_column :quotation_proposal_vendor_items, :gst_percentage, :decimal, precision: 5, scale: 2
  end
end
