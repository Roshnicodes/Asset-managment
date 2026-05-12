class AddTransactionFieldsToInvoiceRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :quotation_proposal_vendor_invoice_requests, :transaction_type, :string
    add_column :quotation_proposal_vendor_invoice_requests, :transaction_no, :string
    add_column :quotation_proposal_vendor_invoice_requests, :transaction_date, :date

    say_with_time "Backfilling finance transaction details from legacy payment advice fields" do
      execute <<~SQL.squish
        UPDATE quotation_proposal_vendor_invoice_requests
        SET
          transaction_type = CASE
            WHEN COALESCE(NULLIF(transaction_type, ''), '') <> '' THEN transaction_type
            WHEN COALESCE(NULLIF(utr_no, ''), '') <> '' OR utr_date IS NOT NULL THEN 'Bank Transfer'
            ELSE transaction_type
          END,
          transaction_no = CASE
            WHEN COALESCE(NULLIF(transaction_no, ''), '') <> '' THEN transaction_no
            WHEN COALESCE(NULLIF(utr_no, ''), '') <> '' THEN utr_no
            ELSE transaction_no
          END,
          transaction_date = COALESCE(transaction_date, utr_date)
        WHERE payment_advice_sent_at IS NOT NULL
      SQL
    end
  end

  def down
    remove_column :quotation_proposal_vendor_invoice_requests, :transaction_date
    remove_column :quotation_proposal_vendor_invoice_requests, :transaction_no
    remove_column :quotation_proposal_vendor_invoice_requests, :transaction_type
  end
end
