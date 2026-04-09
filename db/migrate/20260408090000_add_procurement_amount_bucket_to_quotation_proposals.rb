class AddProcurementAmountBucketToQuotationProposals < ActiveRecord::Migration[8.0]
  def change
    add_column :quotation_proposals, :procurement_amount_bucket, :string, null: false, default: "above_10k"
  end
end
