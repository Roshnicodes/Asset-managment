require "test_helper"

# Payment advice mails go through the ASA mail service (krai) as a signed
# GET link when the server has no SMTP.
class PaymentAdviceMailRelayTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, :message, :success) do
    def is_a?(klass)
      klass == Net::HTTPSuccess ? success : super
    end
  end

  SECRET = "test-shared-secret".freeze

  setup do
    @payment_advice = PaymentAdviceRecord.create!(
      company_name: "Accounts Department",
      advice_no: "PA-2026-950",
      payee_name: "Relay Vendor & Sons",
      payee_email: "relay.vendor@example.com",
      invoice_no: "INV-950",
      gross_amount: 1000,
      tds_amount: 50,
      other_deduction: 25,
      payment_mode: "NEFT",
      reference_no: "UTR950"
    )
  end

  test "calls a signed link with the advice fields, expiry and signature" do
    called = nil
    fake = ->(uri) { called = uri; FakeResponse.new("200", { status: "success" }.to_json, "OK", true) }
    now = Time.zone.local(2026, 10, 5, 12, 0, 0)

    with_env("PAYMENT_ADVICE_MAIL_RELAY_URL" => "https://krai.asaindia.org/", "PAYMENT_ADVICE_MAIL_RELAY_SECRET" => SECRET) do
      PaymentAdviceMailRelay.stub(:get, fake) { assert PaymentAdviceMailRelay.deliver!(@payment_advice, now: now) }
    end

    assert_equal "krai.asaindia.org", called.host
    assert_equal "/nemail.aspx", called.path
    query = URI.decode_www_form(called.query).to_h
    assert_equal "relay.vendor@example.com", query["payee_email"]
    assert_equal "Relay Vendor & Sons", query["payee_name"]
    assert_equal "925.0", query["net_amount"]
    assert_equal (now + 10.minutes).to_i.to_s, query["expires_at"]

    # Same recipe as in the krai integration spec.
    string_to_sign = (PaymentAdviceMailRelay::SIGNED_FIELDS.map { |field| query[field].to_s } + [query["expires_at"]]).join("|")
    assert_equal OpenSSL::HMAC.hexdigest("SHA256", SECRET, string_to_sign), query["signature"]
  end

  test "without a secret the link carries only the advice values" do
    called = nil
    fake = ->(uri) { called = uri; FakeResponse.new("200", { status: "success" }.to_json, "OK", true) }

    with_env("PAYMENT_ADVICE_MAIL_RELAY_SECRET" => nil) do
      PaymentAdviceMailRelay.stub(:get, fake) { assert PaymentAdviceMailRelay.deliver!(@payment_advice) }
    end

    query = URI.decode_www_form(called.query).to_h
    assert_equal PaymentAdviceMailRelay::SIGNED_FIELDS, query.keys
    assert_equal "relay.vendor@example.com", query["payee_email"]
    assert_not query.key?("signature")
    assert_not query.key?("expires_at")
  end

  test "the default link is krai's nemail.aspx page with the parameters in the agreed order" do
    called = nil
    fake = ->(uri) { called = uri; FakeResponse.new("200", "Mail sent", "OK", true) }

    with_env("PAYMENT_ADVICE_MAIL_RELAY_URL" => nil, "PAYMENT_ADVICE_MAIL_RELAY_SECRET" => nil) do
      PaymentAdviceMailRelay.stub(:get, fake) { assert PaymentAdviceMailRelay.deliver!(@payment_advice) }
    end

    assert_equal "https://krai.asaindia.org/nemail.aspx", "#{called.scheme}://#{called.host}#{called.path}"
    assert_equal %w[company_name advice_no payee_name payee_email invoice_no invoice_date gross_amount tds_amount
                    other_deduction net_amount payment_mode reference_no bank_name payment_date remarks],
                 URI.decode_www_form(called.query).map(&:first)
  end

  test "an older bare relay address still goes to nemail.aspx" do
    with_env("PAYMENT_ADVICE_MAIL_RELAY_URL" => "https://krai.asaindia.org/") do
      assert_equal "https://krai.asaindia.org/nemail.aspx", PaymentAdviceMailRelay.url
    end
    with_env("PAYMENT_ADVICE_MAIL_RELAY_URL" => "https://krai.asaindia.org/other.aspx") do
      assert_equal "https://krai.asaindia.org/other.aspx", PaymentAdviceMailRelay.url
    end
  end

  test "an error answer from the mail service is reported" do
    fake = ->(_uri) { FakeResponse.new("200", { success: false, message: "Invalid signature" }.to_json, "OK", true) }

    error = with_env("PAYMENT_ADVICE_MAIL_RELAY_SECRET" => SECRET) do
      assert_raises(PaymentAdviceMailRelay::DeliveryError) do
        PaymentAdviceMailRelay.stub(:get, fake) { PaymentAdviceMailRelay.deliver!(@payment_advice) }
      end
    end
    assert_match "Invalid signature", error.message
  end

  test "an HTTP failure is reported with the status code" do
    fake = ->(_uri) { FakeResponse.new("403", "<h1>403 - Forbidden: Access is denied.</h1>", "Forbidden", false) }

    error = with_env("PAYMENT_ADVICE_MAIL_RELAY_SECRET" => SECRET) do
      assert_raises(PaymentAdviceMailRelay::DeliveryError) do
        PaymentAdviceMailRelay.stub(:get, fake) { PaymentAdviceMailRelay.deliver!(@payment_advice) }
      end
    end
    assert_match "403", error.message
    assert_match "Forbidden", error.message
  end

  test "a network failure becomes a readable error" do
    fake = ->(_uri) { raise Net::OpenTimeout, "execution expired" }

    error = with_env("PAYMENT_ADVICE_MAIL_RELAY_SECRET" => SECRET) do
      assert_raises(PaymentAdviceMailRelay::DeliveryError) do
        PaymentAdviceMailRelay.stub(:get, fake) { PaymentAdviceMailRelay.deliver!(@payment_advice) }
      end
    end
    assert_match "could not be reached", error.message
  end

  test "the relay is used when a relay URL is configured" do
    with_env("PAYMENT_ADVICE_MAIL_RELAY_URL" => "https://krai.asaindia.org/") { assert PaymentAdviceMailRelay.enabled? }
    with_env("PAYMENT_ADVICE_MAIL_RELAY_URL" => nil) { assert_not PaymentAdviceMailRelay.enabled? }
  end

  private

  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
