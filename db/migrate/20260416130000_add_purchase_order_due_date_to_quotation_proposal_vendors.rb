class AddPurchaseOrderDueDateToQuotationProposalVendors < ActiveRecord::Migration[7.1]
  def change
    add_column :quotation_proposal_vendors, :purchase_order_due_date, :date
  end
end
