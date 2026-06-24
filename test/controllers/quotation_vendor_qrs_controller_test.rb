require "test_helper"

class QuotationVendorQrsControllerTest < ActionDispatch::IntegrationTest
  test "routes approved ASA DLT quotation query link format" do
    assert_routing(
      "/xyz",
      controller: "quotation_vendor_qrs",
      action: "approved_link"
    )
  end

  test "routes legacy approved ASA DLT quotation path link format" do
    assert_routing(
      "/xyz/v:13,qp:321",
      controller: "quotation_vendor_qrs",
      action: "approved_link",
      encoded_reference: "v:13,qp:321"
    )
  end

  test "approved link query params redirect to vendor qr token" do
    proposal_vendor = Minitest::Mock.new
    proposal_vendor.expect(:ensure_qr_token!, "generated-token")
    proposal_vendor.expect(:qr_token, "generated-token")

    QuotationProposalVendor.stub(:find_by, proposal_vendor) do
      get "/xyz?v=22&qp=12"
    end

    proposal_vendor.verify

    assert_redirected_to quotation_vendor_qr_path("generated-token")
  end

  test "shows not found page for an invalid vendor token" do
    get quotation_vendor_qr_path("invalid-token")

    assert_response :not_found
    assert_match "This vendor quotation link is invalid or no longer available.", response.body
  end
end
