class AddInvoiceHardCopyReceivedToInvoiceRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :quotation_proposal_vendor_invoice_requests, :invoice_hard_copy_received, :boolean, default: false, null: false
  end
end
