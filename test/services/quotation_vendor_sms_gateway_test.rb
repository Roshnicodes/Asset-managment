require "test_helper"
require "ostruct"

class QuotationVendorSmsGatewayTest < ActiveSupport::TestCase
  test "send_vendor_otp uses approved dlt template, header, and content" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = OpenStruct.new(vendor_name: "G.TECH", mobile_no: "9876543210")
    otp_record = OpenStruct.new(otp_code: "458921")

    Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
      assert QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record)
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177503375571501", params["DLT_TE_ID"]
    assert_equal "1", params["unicode"]
    assert_equal "Dear G.TECH, 458921 is your one-time password to proceed further with the quotation process. Please do not share this OTP. - PLOUGHMAN AGRO PRIVATE LIMITED", params["message"]
  end
end
