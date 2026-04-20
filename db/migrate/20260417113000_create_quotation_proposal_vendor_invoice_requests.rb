class CreateQuotationProposalVendorInvoiceRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :quotation_proposal_vendor_invoice_requests do |t|
      t.references :quotation_proposal_vendor, null: false, foreign_key: true, index: { name: "idx_qp_vendor_invoice_requests_on_proposal_vendor" }
      t.string :request_token, null: false
      t.string :status, null: false, default: "pending_invoice"
      t.text :item_snapshot
      t.text :vendor_remark
      t.datetime :requested_at
      t.datetime :invoice_uploaded_at

      t.timestamps
    end

    add_index :quotation_proposal_vendor_invoice_requests, :request_token, unique: true, name: "idx_qp_vendor_invoice_requests_on_token"
  end
end
