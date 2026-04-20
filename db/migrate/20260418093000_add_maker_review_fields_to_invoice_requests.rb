class AddMakerReviewFieldsToInvoiceRequests < ActiveRecord::Migration[8.1]
  def change
    change_table :quotation_proposal_vendor_invoice_requests, bulk: true do |t|
      t.text :maker_review_remark
      t.datetime :maker_reviewed_at
      t.datetime :accepted_at
      t.datetime :returned_at
      t.references :maker_reviewed_by, foreign_key: { to_table: :employee_masters }, index: { name: "idx_invoice_requests_on_maker_reviewed_by" }
    end
  end
end
