require "test_helper"

class QuotationVendorQrsControllerTest < ActionDispatch::IntegrationTest
  test "routes approved ASA DLT quotation link format" do
    assert_routing(
      "/xyz/v:13,qp:321",
      controller: "quotation_vendor_qrs",
      action: "approved_link",
      encoded_reference: "v:13,qp:321"
    )
  end

  test "shows not found page for an invalid vendor token" do
    get quotation_vendor_qr_path("invalid-token")

    assert_response :not_found
    assert_match "This vendor quotation link is invalid or no longer available.", response.body
  end
end
