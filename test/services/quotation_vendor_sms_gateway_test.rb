require "test_helper"
require "ostruct"

class QuotationVendorSmsGatewayTest < ActiveSupport::TestCase
  AsaDispatchStub = Struct.new(
    :vendor_name,
    :mobile_no,
    :stakeholder_category,
    :quotation_proposal,
    :vendor_registration,
    :quotation_proposal_vendor,
    keyword_init: true
  )

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
    assert_equal "json", params["response"]
    assert_nil params["unicode"]
    assert_nil params["senderid"]
    assert_nil params["header"]
    assert_equal "Dear G.TECH, PLOUGHMAN AGRO PRIVATE LIMITED requests you to review and accept the quotation proposal 123. Please submit the quotation using the following link: https://asa360.asaindia.org/q/secure-token.", params["message"]
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
    assert_equal "json", params["response"]
    assert_nil params["unicode"]
    assert_nil params["senderid"]
    assert_nil params["header"]
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
    assert_equal "json", params["response"]
  end

  test "send_vendor_otp uses ASA-specific credentials and sender for ASA stakeholders" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = AsaDispatchStub.new(
      vendor_name: "G.TECH",
      mobile_no: "9876543210",
      stakeholder_category: OpenStruct.new(name: "ASA")
    )
    otp_record = OpenStruct.new(otp_code: "458921")

    ENV.stub(
      :fetch,
      ->(key, default = nil) do
        {
          "ASA_SMS_AUTHKEY" => "asa-authkey",
          "ASA_SMS_DLT_PE_ID" => "asa-pe-id",
          "ASA_SMS_SENDER" => "ACTFSA"
        }.fetch(key, default)
      end
    ) do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "asa-authkey", params["authkey"]
    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177528687356932", params["DLT_TE_ID"]
    assert_equal "asa-pe-id", params["PE_ID"]
    assert_equal "asa-pe-id", params["DLT_PE_ID"]
    assert_equal "json", params["response"]
    assert_nil params["unicode"]
    assert_equal "Dear G.TECH, 458921 is your one-time password to proceed with the quotation process. Please do not share this OTP. - ACTION FOR SOCIAL ADVANCEMENT", params["message"]
  end

  test "send_vendor_link uses ASA default authkey, sender, template, and content for ASA stakeholders" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = AsaDispatchStub.new(
      vendor_name: "GTec Solution",
      mobile_no: "9876543210",
      stakeholder_category: OpenStruct.new(name: "ASA"),
      quotation_proposal_id: 123,
      quotation_proposal_vendor: OpenStruct.new(qr_token: "secure-token")
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_vendor_link(dispatch)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "3230666f72736131353261", params["authkey"]
    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177512006405172", params["DLT_TE_ID"]
    assert_equal "json", params["response"]
    assert_nil params["unicode"]
    assert_equal "Dear GTEC SOLUTION, We kindly request you to accept the Quotation Proposal: 123. Please submit the quotation through link: https://asa360.asaindia.org/q/secure-token. - ACTION FOR SOCIAL ADVANCEMENT", params["message"]
  end

  test "send_vendor_link prefers vendor stakeholder when resolving sms profile" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = AsaDispatchStub.new(
      vendor_name: "GTec Solution",
      mobile_no: "9876543210",
      quotation_proposal_vendor: OpenStruct.new(qr_token: "secure-token"),
      quotation_proposal: OpenStruct.new(
        id: 123,
        theme: OpenStruct.new(
          stakeholder_category: OpenStruct.new(name: "PAPL")
        )
      ),
      vendor_registration: OpenStruct.new(
        stakeholder_category: OpenStruct.new(name: "ASA")
      )
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_vendor_link(dispatch)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "3230666f72736131353261", params["authkey"]
    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177512006405172", params["DLT_TE_ID"]
  end

  test "send_vendor_otp adds unicode flag only when message contains non ascii text" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = OpenStruct.new(vendor_name: "G.TECH TEST", mobile_no: "9876543210")
    otp_record = OpenStruct.new(otp_code: "458921")

    QuotationVendorSmsGateway.stub(
      :sms_vendor_name,
      "G.TECH TEST \u091f\u0947\u0938\u094d\u091f"
    ) do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "1", params["unicode"]
    assert_equal "json", params["response"]
  end

  test "send_vendor_otp does not fallback to default sender when ASA sender is rejected" do
    request_count = 0
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Failed","Code":"004","Description":"Kindly provide sender-id."}'
    end

    dispatch = AsaDispatchStub.new(
      vendor_name: "G.TECH",
      mobile_no: "9876543210",
      stakeholder_category: OpenStruct.new(name: "ASA")
    )
    otp_record = OpenStruct.new(otp_code: "458921")

    Net::HTTP.stub(:get_response, ->(_uri) { request_count += 1; response }) do
      assert_not QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record)
    end

    assert_equal 1, request_count
  end
end
