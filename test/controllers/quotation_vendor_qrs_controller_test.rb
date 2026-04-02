require "test_helper"

class QuotationVendorQrsControllerTest < ActionDispatch::IntegrationTest
  test "shows not found page for an invalid vendor token" do
    get quotation_vendor_qr_path("invalid-token")

    assert_response :not_found
    assert_match "This vendor quotation link is invalid or no longer available.", response.body
  end
end
