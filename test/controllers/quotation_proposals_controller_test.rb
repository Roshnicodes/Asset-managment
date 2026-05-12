require "test_helper"

class QuotationProposalsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @finance_user = users(:one)
    @finance_user.update!(role: :admin)
    sign_in @finance_user

    @proposal = QuotationProposal.new(
      theme: themes(:one),
      user: @finance_user,
      subject: "Finance Queue Test Proposal",
      proposal_end_date: Date.new(2026, 5, 30),
      remark: "Test proposal",
      workflow_status: "vendor_selected",
      procurement_amount_bucket: "above_10k"
    )
    @proposal.save!(validate: false)

    @proposal_vendor = QuotationProposalVendor.create!(
      quotation_proposal: @proposal,
      vendor_registration: vendor_registrations(:one)
    )

    @invoice_request = @proposal_vendor.invoice_requests.create!(
      status: "accepted",
      pdo_no: "PDO-100",
      rfp_no: "RFP-100",
      rfp_created_on: Date.new(2026, 5, 12),
      requested_at: Time.current,
      payment_reference_marked_at: Time.current
    )

    @second_invoice_request = @proposal_vendor.invoice_requests.create!(
      status: "accepted",
      pdo_no: "PDO-101",
      rfp_no: "RFP-101",
      rfp_created_on: Date.new(2026, 5, 12),
      requested_at: Time.current,
      payment_reference_marked_at: Time.current
    )
  end

  test "finance can save shared transaction details for selected invoices without triggering sms" do
    QuotationVendorSmsGateway.stub(:send_payment_advice, ->(*) { flunk "SMS should not be triggered while API is pending" }) do
      patch update_payment_advice_quotation_proposals_path, params: {
        invoice_request_ids: [@invoice_request.id, @second_invoice_request.id],
        transaction_type: "NEFT",
        transaction_no: "TXN-9001",
        transaction_date: "2026-05-12"
      }
    end

    assert_redirected_to payment_advice_quotation_proposals_path

    @invoice_request.reload
    @second_invoice_request.reload

    assert_equal "NEFT", @invoice_request.transaction_type
    assert_equal "TXN-9001", @invoice_request.transaction_no
    assert_equal Date.new(2026, 5, 12), @invoice_request.transaction_date
    assert_not_nil @invoice_request.payment_advice_sent_at

    assert_equal "NEFT", @second_invoice_request.transaction_type
    assert_equal "TXN-9001", @second_invoice_request.transaction_no
    assert_equal Date.new(2026, 5, 12), @second_invoice_request.transaction_date
    assert_not_nil @second_invoice_request.payment_advice_sent_at
  end
end
