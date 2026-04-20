class AddPaymentWorkflowFieldsToInvoiceRequests < ActiveRecord::Migration[8.1]
  def change
    change_table :quotation_proposal_vendor_invoice_requests, bulk: true do |t|
      t.string :pdo_no
      t.string :rfp_no
      t.date :rfp_created_on
      t.datetime :payment_reference_marked_at
      t.references :payment_reference_marked_by, foreign_key: { to_table: :employee_masters }, index: { name: "idx_invoice_requests_on_payment_ref_by" }
      t.string :utr_no
      t.date :utr_date
      t.string :asa_bank_name
      t.string :asa_account_no
      t.datetime :payment_advice_sent_at
      t.references :payment_advice_updated_by, foreign_key: { to_table: :employee_masters }, index: { name: "idx_invoice_requests_on_payment_advice_by" }
    end
  end
end
