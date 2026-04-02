require "test_helper"
require "ostruct"

class QuotationVendorSmsGatewayTest < ActiveSupport::TestCase
  test "send_vendor_link uses approved dlt template, header, and content" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = OpenStruct.new(
      vendor_name: "G.TECH",
      mobile_no: "9876543210",
      quotation_proposal_id: 123,
      quotation_proposal_vendor: OpenStruct.new(qr_token: "secure-token")
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_vendor_link(dispatch)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177502703834106", params["DLT_TE_ID"]
    assert_equal "1", params["unicode"]
    assert_equal "Dear G.TECH, PLOUGHMAN AGRO PRIVATE LIMITED requests you to review and accept the quotation proposal 123. Please submit the quotation using the following link: https://asa360.asaindia.org/vendor_registrations/new.", params["message"]
  end

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

  test "send_vendor_link includes pe id when configured" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = OpenStruct.new(
      vendor_name: "G.TECH",
      mobile_no: "9876543210",
      quotation_proposal_id: 123,
      quotation_proposal_vendor: OpenStruct.new(qr_token: "secure-token")
    )

    ENV.stub(:[], ->(key) { key == "SMS_DLT_PE_ID" ? "1701168512345678901" : nil }) do
      QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
        Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
          assert QuotationVendorSmsGateway.send_vendor_link(dispatch)
        end
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "1701168512345678901", params["PE_ID"]
    assert_equal "1701168512345678901", params["DLT_PE_ID"]
  end
end
