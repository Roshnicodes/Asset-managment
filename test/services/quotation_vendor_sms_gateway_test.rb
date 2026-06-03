require "test_helper"
require "ostruct"

class QuotationVendorSmsGatewayTest < ActiveSupport::TestCase
  AsaDispatchStub = Struct.new(
    :vendor_name,
    :mobile_no,
    :quotation_proposal_id,
    :stakeholder_category,
    :quotation_proposal,
    :vendor_registration,
    :quotation_proposal_vendor,
    keyword_init: true
  )

  test "base_url prefers APP_BASE_URL and strips trailing slash" do
    with_env("APP_BASE_URL" => "https://asa360.asaindia.org/") do
      assert_equal "https://asa360.asaindia.org", QuotationVendorSmsGateway.base_url
    end
  end

  test "base_url uses route default url options when APP_BASE_URL is blank" do
    with_env("APP_BASE_URL" => nil) do
      with_route_default_url_options(host: "asa360.asaindia.org", protocol: "https") do
        assert_equal "https://asa360.asaindia.org", QuotationVendorSmsGateway.base_url
      end
    end
  end

  test "all vendor sms links use the configured base_url" do
    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      assert_equal "https://asa360.asaindia.org/q/quote-token", QuotationVendorSmsGateway.vendor_link_for("quote-token")
      assert_equal "https://asa360.asaindia.org/p/po-token", QuotationVendorSmsGateway.purchase_order_link_for("po-token")
      assert_equal "https://asa360.asaindia.org/gr/invoice-token", QuotationVendorSmsGateway.goods_receive_invoice_link_for("invoice-token")
    end
  end

  test "vendor sms links can use stakeholder specific approved base urls" do
    with_env(
      "APP_BASE_URL" => "https://global.example.org",
      "ASA_APP_BASE_URL" => "https://asa-approved.example.org",
      "SMS_APP_BASE_URL" => "https://papl-approved.example.org"
    ) do
      assert_equal(
        "https://asa-approved.example.org/q/quote-token",
        QuotationVendorSmsGateway.vendor_link_for_config("quote-token", config: { profile: :asa })
      )
      assert_equal(
        "https://papl-approved.example.org/q/quote-token",
        QuotationVendorSmsGateway.vendor_link_for_config("quote-token", config: { profile: :default })
      )
    end
  end

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
    assert_equal "91", params["country"]
    assert_equal "1707177502703834106", params["DLT_TE_ID"]
    assert_equal "json", params["response"]
    assert_nil params["unicode"]
    assert_nil params["senderid"]
    assert_nil params["header"]
    assert_equal "Dear G.TECH, PLOUGHMAN AGRO PRIVATE LIMITED requests you to review and accept the quotation proposal 123. Please submit the quotation using the following link: https://asa360.asaindia.org/q?t=secure-token.", params["message"]
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

  test "send_purchase_order_link uses dedicated dlt template and content" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    quotation_proposal = OpenStruct.new(
      id: 123,
      theme: OpenStruct.new(
        stakeholder_category: OpenStruct.new(name: "PLOAPL")
      )
    )
    dispatch = OpenStruct.new(
      vendor_name: "SUNIL CHOUBEY",
      mobile_no: "9876543210",
      quotation_proposal: quotation_proposal
    )
    proposal_vendor = OpenStruct.new(
      po_token: "qO7wmv7tqEEV",
      quotation_proposal: quotation_proposal
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_purchase_order_link(dispatch, proposal_vendor)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h
    expected_year_label = "#{Date.current.year}-#{(Date.current.year + 1).to_s.last(2)}"

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177641694704075", params["DLT_TE_ID"]
    assert_equal "Dear SUNIL CHOUBEY, We kindly request you to accept the purchase order: PLOAPL/PO/123/#{expected_year_label}.through link: https://asa360.asaindia.org/p?t=qO7wmv7tqEEV. - Ploughman Agro Private Limited", params["message"]
  end

  test "send_vendor_otp uses dedicated purchase order dlt template and content" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = OpenStruct.new(vendor_name: "G.TECH", mobile_no: "9876543210")
    otp_record = OpenStruct.new(otp_code: "458921")

    Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
      assert QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record, purpose: :purchase_order)
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177641235050439", params["DLT_TE_ID"]
    assert_equal "Dear G.TECH, 458921 is your one-time password to proceed with the purchase order process. Please do not share this OTP. - Ploughman Agro Private Limited (PAPL)", params["message"]
  end

  test "send_goods_receive_invoice_link uses PAPL invoice template for PGPL stakeholders" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    quotation_proposal = OpenStruct.new(
      id: 102,
      theme: OpenStruct.new(
        stakeholder_category: OpenStruct.new(name: "PGPL")
      )
    )
    dispatch = OpenStruct.new(
      vendor_name: "SUNIL CHOUBEY",
      mobile_no: "9876543210",
      quotation_proposal: quotation_proposal
    )
    proposal_vendor = OpenStruct.new(quotation_proposal: quotation_proposal)
    invoice_request = OpenStruct.new(
      request_token: "qO7wmv7tqEEV",
      quotation_proposal_vendor: proposal_vendor
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_goods_receive_invoice_link(dispatch, invoice_request)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h
    expected_year_label = "#{Date.current.year}-#{(Date.current.year + 1).to_s.last(2)}"

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177648937573645", params["DLT_TE_ID"]
    assert_equal "Dear SUNIL CHOUBEY, We kindly request you to upload the invoice for the purchase order: PGPL/PO/102/#{expected_year_label}.through link: https://asa360.asaindia.org/p?t=qO7wmv7tqEEV. - Ploughman Agro Private Limited (PAPL)", params["message"]
  end

  test "send_goods_receive_invoice_return_link uses PAPL rejected invoice template for PGPL stakeholders" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    quotation_proposal = OpenStruct.new(
      id: 102,
      theme: OpenStruct.new(
        stakeholder_category: OpenStruct.new(name: "PGPL")
      )
    )
    dispatch = OpenStruct.new(
      vendor_name: "Sunil Choubey",
      mobile_no: "9876543210",
      quotation_proposal: quotation_proposal
    )
    proposal_vendor = OpenStruct.new(quotation_proposal: quotation_proposal)
    invoice_request = OpenStruct.new(
      request_token: "qO7wmv7tqEEV",
      quotation_proposal_vendor: proposal_vendor
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_goods_receive_invoice_return_link(dispatch, invoice_request)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h
    expected_year_label = "#{Date.current.year}-#{(Date.current.year + 1).to_s.last(2)}"

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177650435445886", params["DLT_TE_ID"]
    assert_equal "Dear Sunil Choubey, Your invoice has been rejected. Please upload a revised invoice for PO: PGPL/PO/102/#{expected_year_label} using the link below: https://asa360.asaindia.org/p?t=qO7wmv7tqEEV. - Ploughman Agro Private Limited (PAPL)", params["message"]
  end

  test "send_vendor_otp uses PAPL invoice otp template and content" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    dispatch = OpenStruct.new(vendor_name: "G.TECH", mobile_no: "9876543210")
    otp_record = OpenStruct.new(otp_code: "458921")

    Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
      assert QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record, purpose: :invoice)
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177675366996869", params["DLT_TE_ID"]
    assert_equal "Dear G.TECH, 458921 is your one-time password to proceed with the invoice for purchase order process. Please do not share this OTP. - Ploughman Agro Private Limited (PAPL)", params["message"]
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

    ENV.stub(
      :fetch,
      ->(key, default = nil) do
        {
          "SMS_DLT_PE_ID" => "1701168512345678901"
        }.fetch(key, default)
      end
    ) do
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

  test "send_purchase_order_link uses ASA purchase order template and content for ASA stakeholders" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    quotation_proposal = OpenStruct.new(
      id: 123,
      theme: OpenStruct.new(
        stakeholder_category: OpenStruct.new(name: "ASA")
      )
    )
    dispatch = AsaDispatchStub.new(
      vendor_name: "GTec Solution",
      mobile_no: "9876543210",
      stakeholder_category: OpenStruct.new(name: "ASA"),
      quotation_proposal: quotation_proposal
    )
    proposal_vendor = OpenStruct.new(
      po_token: "qO7wmv7tqEEV",
      quotation_proposal: quotation_proposal
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_purchase_order_link(dispatch, proposal_vendor)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h
    expected_year_label = "#{Date.current.year}-#{(Date.current.year + 1).to_s.last(2)}"

    assert_equal "3230666f72736131353261", params["authkey"]
    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177632997145777", params["DLT_TE_ID"]
    assert_equal "Dear GTEC SOLUTION, We kindly request you to accept the purchase order: ASA/PO/123/#{expected_year_label}.through link: https://asa360.asaindia.org/p?t=qO7wmv7tqEEV. - Action for social advancement (ASA)", params["message"]
  end

  test "send_vendor_otp uses ASA purchase order template and content for ASA stakeholders" do
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

    Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
      assert QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record, purpose: :purchase_order)
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177633788078441", params["DLT_TE_ID"]
    assert_equal "Dear G.TECH, 458921 is your one-time password to proceed with the purchase order process. Please do not share this OTP. - Action for social advancement", params["message"]
  end

  test "send_goods_receive_invoice_link uses ASA invoice template and content for ASA stakeholders" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    quotation_proposal = OpenStruct.new(
      id: 102,
      theme: OpenStruct.new(
        stakeholder_category: OpenStruct.new(name: "ASA")
      )
    )
    dispatch = AsaDispatchStub.new(
      vendor_name: "Sunil Choubey",
      mobile_no: "9876543210",
      stakeholder_category: OpenStruct.new(name: "ASA"),
      quotation_proposal: quotation_proposal
    )
    proposal_vendor = OpenStruct.new(quotation_proposal: quotation_proposal)
    invoice_request = OpenStruct.new(
      request_token: "qO7wmv7tqEEV",
      quotation_proposal_vendor: proposal_vendor
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_goods_receive_invoice_link(dispatch, invoice_request)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h
    expected_year_label = "#{Date.current.year}-#{(Date.current.year + 1).to_s.last(2)}"

    assert_equal "3230666f72736131353261", params["authkey"]
    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177674942135728", params["DLT_TE_ID"]
    assert_equal "Dear SUNIL CHOUBEY, We kindly request you to upload the invoice for the purchase order: ASA/PO/102/#{expected_year_label}.through link: https://asa360.asaindia.org/p?t=qO7wmv7tqEEV. - Action For Social Advancement(ASA)", params["message"]
  end

  test "send_goods_receive_invoice_return_link uses ASA rejected invoice template and content for ASA stakeholders" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    quotation_proposal = OpenStruct.new(
      id: 102,
      theme: OpenStruct.new(
        stakeholder_category: OpenStruct.new(name: "ASA")
      )
    )
    dispatch = AsaDispatchStub.new(
      vendor_name: "Sunil Choubey",
      mobile_no: "9876543210",
      stakeholder_category: OpenStruct.new(name: "ASA"),
      quotation_proposal: quotation_proposal
    )
    proposal_vendor = OpenStruct.new(quotation_proposal: quotation_proposal)
    invoice_request = OpenStruct.new(
      request_token: "qO7wmv7tqEEV",
      quotation_proposal_vendor: proposal_vendor
    )

    QuotationVendorSmsGateway.stub(:base_url, "https://asa360.asaindia.org") do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_goods_receive_invoice_return_link(dispatch, invoice_request)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h
    expected_year_label = "#{Date.current.year}-#{(Date.current.year + 1).to_s.last(2)}"

    assert_equal "3230666f72736131353261", params["authkey"]
    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177674947419559", params["DLT_TE_ID"]
    assert_equal "Dear SUNIL CHOUBEY, Your invoice has been rejected. Please upload a revised invoice for PO: ASA/PO/102/#{expected_year_label} using the link below:https://asa360.asaindia.org/p?t=qO7wmv7tqEEV.-Action For Social Advancement (ASA)", params["message"]
  end

  test "send_vendor_otp uses ASA invoice otp template and content for ASA stakeholders" do
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

    Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
      assert QuotationVendorSmsGateway.send_vendor_otp(dispatch, otp_record, purpose: :invoice)
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "ACTFSA", params["sender"]
    assert_equal "1707177675358503792", params["DLT_TE_ID"]
    assert_equal "Dear G.TECH, 458921 is your one-time password to proceed with the invoice for purchase order process. Please do not share this OTP. - Action for social advancement", params["message"]
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
      quotation_proposal_vendor: OpenStruct.new(id: 13, qr_token: "secure-token")
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
    assert_equal "Dear GTEC SOLUTION, We kindly request you to accept the Quotation Proposal: 123. Please submit the quotation through link: https://asa360.asaindia.org/xyz?v=13&qp=123. - ACTION FOR SOCIAL ADVANCEMENT", params["message"]
  end

  test "send_vendor_link falls back to token link when ASA approved link ids are unavailable" do
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

    assert_equal "Dear GTEC SOLUTION, We kindly request you to accept the Quotation Proposal: 123. Please submit the quotation through link: https://asa360.asaindia.org/q?t=secure-token. - ACTION FOR SOCIAL ADVANCEMENT", params["message"]
  end

  test "send_vendor_link prefers quotation stakeholder when resolving sms profile" do
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

    assert_equal "37317061706c39353312", params["authkey"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177502703834106", params["DLT_TE_ID"]
  end

  test "send_vendor_link routes PGPL stakeholder through PAPL sms api" do
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
          stakeholder_category: OpenStruct.new(name: "PGPL")
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

    assert_equal "37317061706c39353312", params["authkey"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177502703834106", params["DLT_TE_ID"]
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

  test "send_sms fails before gateway call when message URL uses placeholder host" do
    request_count = 0
    message = "Dear Vendor, link: https://example.com/p/token"

    QuotationVendorSmsGateway.stub(:local_runtime_environment?, false) do
      Net::HTTP.stub(:get_response, ->(_uri) { request_count += 1; flunk "gateway should not be called" }) do
        assert_not QuotationVendorSmsGateway.send_sms(
          mobile_no: "9876543210",
          message: message,
          template_id: "template-id",
          config: QuotationVendorSmsGateway.asa_sms_config
        )
      end
    end

    assert_equal 0, request_count
    assert_match "SMS link is using example.com", QuotationVendorSmsGateway.last_error_message
  end

  test "send_sms fails before gateway call when URL host is not allowed" do
    request_count = 0
    message = "Dear Vendor, link: https://asa360.asaindia.org/p/token"

    with_env("ASA_SMS_ALLOWED_URL_HOSTS" => "apurti.ploughmanagro.com") do
      Net::HTTP.stub(:get_response, ->(_uri) { request_count += 1; flunk "gateway should not be called" }) do
        assert_not QuotationVendorSmsGateway.send_sms(
          mobile_no: "9876543210",
          message: message,
          template_id: "template-id",
          config: QuotationVendorSmsGateway.asa_sms_config
        )
      end
    end

    assert_equal 0, request_count
    assert_match "SMS link host asa360.asaindia.org is not in the approved SMS URL hosts", QuotationVendorSmsGateway.last_error_message
  end

  test "send_sms fails before gateway call when mobile number is invalid" do
    request_count = 0

    Net::HTTP.stub(:get_response, ->(_uri) { request_count += 1; flunk "gateway should not be called" }) do
      assert_not QuotationVendorSmsGateway.send_sms(
        mobile_no: "12345",
        message: "Dear Vendor, test message",
        template_id: "template-id",
        config: QuotationVendorSmsGateway.default_sms_config
      )
    end

    assert_equal 0, request_count
    assert_match "SMS mobile number 12345 is invalid", QuotationVendorSmsGateway.last_error_message
  end

  test "send_sms normalizes india country code before gateway call" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
      assert QuotationVendorSmsGateway.send_sms(
        mobile_no: "+91 98765 43210",
        message: "Dear Vendor, test message",
        template_id: "template-id",
        config: QuotationVendorSmsGateway.default_sms_config
      )
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "9876543210", params["mobiles"]
    assert_equal "91", params["country"]
  end

  test "provider invalid destination DLR is converted to readable support message" do
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Failed","Code":"1025","Description":"EC_OR_invalidDestinationReference"}'
    end

    Net::HTTP.stub(:get_response, ->(_uri) { response }) do
      assert_not QuotationVendorSmsGateway.send_sms(
        mobile_no: "9876543210",
        message: "Dear Vendor, test message",
        template_id: "template-id",
        config: QuotationVendorSmsGateway.default_sms_config
      )
    end

    assert_match "SMS provider rejected the destination reference", QuotationVendorSmsGateway.last_error_message
    assert_match "SMS CTA URL is whitelisted", QuotationVendorSmsGateway.last_error_message
  end

  test "vendor registration sms config uses live vendor registration base url" do
    with_env(
      "APP_BASE_URL" => "https://wrong.example.org",
      "SMS_APP_BASE_URL" => "https://quotation.example.org",
      "SMS_VENDOR_REGISTRATION_CTA_URL" => nil,
      "VENDOR_REGISTRATION_APP_BASE_URL" => "http://apurti.ploughmanagro.com"
    ) do
      config = QuotationVendorSmsGateway.vendor_registration_sms_config

      assert_equal :vendor_registration, config[:profile]
      assert_equal(
        "http://apurti.ploughmanagro.com/vr?inviteToken1",
        QuotationVendorSmsGateway.vendor_registration_sms_link_for_config("inviteToken1", config: config)
      )
    end
  end

  test "vendor registration sms link can use exact whitelisted CTA url override" do
    with_env(
      "VENDOR_REGISTRATION_APP_BASE_URL" => "http://apurti.ploughmanagro.com",
      "SMS_VENDOR_REGISTRATION_CTA_URL" => "http://apurti.ploughmanagro.com/vr?"
    ) do
      config = QuotationVendorSmsGateway.vendor_registration_sms_config

      assert_equal(
        "http://apurti.ploughmanagro.com/vr?inviteToken1",
        QuotationVendorSmsGateway.vendor_registration_sms_link_for_config("inviteToken1", config: config)
      )
    end
  end

  test "vendor registration sms link defaults to approved production CTA url" do
    with_env(
      "APP_BASE_URL" => nil,
      "SMS_APP_BASE_URL" => nil,
      "PAPL_APP_BASE_URL" => nil,
      "VENDOR_REGISTRATION_APP_BASE_URL" => nil,
      "SMS_VENDOR_REGISTRATION_CTA_URL" => nil
    ) do
      QuotationVendorSmsGateway.stub(:local_runtime_environment?, false) do
        config = QuotationVendorSmsGateway.vendor_registration_sms_config

        assert_equal(
          "http://apurti.ploughmanagro.com/vr?inviteToken1",
          QuotationVendorSmsGateway.vendor_registration_sms_link_for_config("inviteToken1", config: config)
        )
      end
    end
  end

  test "send_vendor_registration_link uses approved template header and content" do
    captured_uri = nil
    response = Net::HTTPOK.new("1.1", "200", "OK")

    def response.body
      '{"Status":"Success","Code":"000","Description":"Sent"}'
    end

    invitation = OpenStruct.new(
      mobile_no: "9876543210",
      token: "inviteToken1"
    )

    with_env(
      "VENDOR_REGISTRATION_APP_BASE_URL" => "http://apurti.ploughmanagro.com",
      "SMS_VENDOR_REGISTRATION_CTA_URL" => nil,
      "SMS_ALLOWED_URL_HOSTS" => "apurti.ploughmanagro.com"
    ) do
      Net::HTTP.stub(:get_response, ->(uri) { captured_uri = uri; response }) do
        assert QuotationVendorSmsGateway.send_vendor_registration_link(invitation)
      end
    end

    params = URI.decode_www_form(captured_uri.query).to_h

    assert_equal "9876543210", params["mobiles"]
    assert_equal "PLOAPL", params["sender"]
    assert_equal "1707177944223861381", params["DLT_TE_ID"]
    assert_equal "Dear Vendor, Please registration using the link below: http://apurti.ploughmanagro.com/vr?inviteToken1 Ploughman Agro Private Limited (PAPL)", params["message"]
  end

  private

  def with_env(values)
    previous_values = values.transform_values { |_value| nil }
    values.each_key { |key| previous_values[key] = ENV[key] }
    values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    previous_values.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  def with_route_default_url_options(options)
    default_options = Rails.application.routes.default_url_options
    previous_options = default_options.dup
    default_options.clear
    default_options.merge!(options)

    yield
  ensure
    default_options.clear
    default_options.merge!(previous_options)
  end

  test "vendor links fall back to mailer host when route host is not configured" do
    original_app_base_url = ENV.delete("APP_BASE_URL")
    original_routes_default_url_options = Rails.application.routes.default_url_options
    original_mailer_default_url_options = Rails.application.config.action_mailer.default_url_options

    Rails.application.routes.default_url_options = {}
    Rails.application.config.action_mailer.default_url_options = {
      host: "apurti.ploughmanagro.com",
      protocol: "https"
    }

    assert_equal "https://apurti.ploughmanagro.com", QuotationVendorSmsGateway.configured_base_url
    assert_equal "https://apurti.ploughmanagro.com/q/secure-token", QuotationVendorSmsGateway.vendor_link_for("secure-token")
    assert_equal "https://apurti.ploughmanagro.com/p/secure-token", QuotationVendorSmsGateway.purchase_order_link_for("secure-token")
    assert_equal "https://apurti.ploughmanagro.com/gr/secure-token", QuotationVendorSmsGateway.goods_receive_invoice_link_for("secure-token")
  ensure
    if original_app_base_url.present?
      ENV["APP_BASE_URL"] = original_app_base_url
    else
      ENV.delete("APP_BASE_URL")
    end

    Rails.application.routes.default_url_options = original_routes_default_url_options
    Rails.application.config.action_mailer.default_url_options = original_mailer_default_url_options
  end
end
