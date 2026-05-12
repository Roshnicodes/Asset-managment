require "test_helper"

class QuotationProposalVendorInvoiceRequestTest < ActiveSupport::TestCase
  test "payment transaction helpers prefer finance transaction fields" do
    invoice_request = QuotationProposalVendorInvoiceRequest.new(
      status: "accepted",
      transaction_type: "NEFT",
      transaction_no: "TXN-101",
      transaction_date: Date.new(2026, 5, 12),
      utr_no: "LEGACY-1",
      utr_date: Date.new(2026, 5, 1)
    )

    assert invoice_request.finance_transaction_recorded?
    assert_equal "NEFT", invoice_request.payment_transaction_type
    assert_equal "TXN-101", invoice_request.payment_transaction_no
    assert_equal Date.new(2026, 5, 12), invoice_request.payment_transaction_date
    assert_not invoice_request.legacy_payment_advice_details?
  end

  test "payment transaction helpers fall back to legacy payment advice values" do
    invoice_request = QuotationProposalVendorInvoiceRequest.new(
      status: "accepted",
      utr_no: "UTR-404",
      utr_date: Date.new(2026, 5, 8),
      asa_bank_name: "ASA Bank",
      asa_account_no: "1234567890"
    )

    assert_not invoice_request.finance_transaction_recorded?
    assert_equal "Bank Transfer", invoice_request.payment_transaction_type
    assert_equal "UTR-404", invoice_request.payment_transaction_no
    assert_equal Date.new(2026, 5, 8), invoice_request.payment_transaction_date
    assert invoice_request.legacy_payment_advice_details?
  end

  test "payment advice pending and advised states reflect finance progress" do
    invoice_request = QuotationProposalVendorInvoiceRequest.new(
      status: "accepted",
      pdo_no: "PDO-12",
      rfp_no: "RFP-12",
      rfp_created_on: Date.new(2026, 5, 12)
    )

    assert invoice_request.payment_advice_pending?

    invoice_request.payment_advice_sent_at = Time.current
    assert invoice_request.payment_advised?
    assert_not invoice_request.payment_advice_pending?
  end
end
