require "test_helper"

class PaymentAdvicesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    EmployeeMaster.create!(
      name: "Finance Mail User",
      employee_code: "FIN-MAIL",
      email_id: @user.email,
      designation: "Senior Manager Finance",
      user_type: "User",
      stakeholder_category: stakeholder_categories(:one)
    )
    sign_in @user

    ActionMailer::Base.deliveries.clear
    @payment_advice = PaymentAdviceRecord.create!(
      company_name: "Accounts Department",
      advice_no: "PA-2026-901",
      payee_name: "Original Vendor",
      payee_email: "old.vendor@example.com",
      invoice_no: "INV-901",
      gross_amount: 1000,
      tds_amount: 50,
      other_deduction: 25,
      payment_mode: "NEFT"
    )
  end

  test "send mail keeps existing saved recipient flow" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post send_mail_payment_advice_path(@payment_advice), as: :json
    end

    assert_response :success
    assert_equal ["old.vendor@example.com"], ActionMailer::Base.deliveries.last.to
  end

  test "send mail uses edited recipient email from current form payload" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post send_mail_payment_advice_path(@payment_advice),
        params: {
          payment_advice: {
            company_name: "Accounts Department",
            advice_no: @payment_advice.advice_no,
            payee_name: "Original Vendor",
            payee_email: "new.vendor@example.com",
            invoice_no: "INV-901",
            gross_amount: 1000,
            tds_amount: 50,
            other_deduction: 25,
            payment_mode: "NEFT"
          }
        },
        as: :json
    end

    assert_response :success
    assert_equal ["new.vendor@example.com"], ActionMailer::Base.deliveries.last.to
    assert_equal "new.vendor@example.com", @payment_advice.reload.payee_email
  end

  test "send mail goes through the ASA mail service when it is configured" do
    sent_to = nil
    ok = Struct.new(:code, :body, :message) { def is_a?(klass) = klass == Net::HTTPSuccess || super }.new("200", "{}", "OK")
    ENV["PAYMENT_ADVICE_MAIL_RELAY_URL"] = "https://krai.asaindia.org/"
    ENV["PAYMENT_ADVICE_MAIL_RELAY_SECRET"] = "test-shared-secret"

    PaymentAdviceMailRelay.stub(:get, ->(uri) { sent_to = URI.decode_www_form(uri.query).to_h["payee_email"]; ok }) do
      assert_no_difference -> { ActionMailer::Base.deliveries.size } do
        post send_mail_payment_advice_path(@payment_advice), as: :json
      end
    end

    assert_response :success
    assert_equal "old.vendor@example.com", sent_to
    assert_equal "Payment advice sent to old.vendor@example.com.", response.parsed_body["message"]
  ensure
    ENV.delete("PAYMENT_ADVICE_MAIL_RELAY_URL")
    ENV.delete("PAYMENT_ADVICE_MAIL_RELAY_SECRET")
  end

  test "saving a new advice never overwrites another advice with the same number" do
    assert_no_difference -> { PaymentAdviceRecord.count } do
      post payment_advices_path, params: { payment_advice: advice_params(advice_no: @payment_advice.advice_no, payee_name: "Other Vendor") }, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "Original Vendor", @payment_advice.reload.payee_name
  end

  test "a saved advice is edited by its id" do
    post payment_advices_path, params: { record_id: @payment_advice.id, payment_advice: advice_params(payee_name: "Edited Vendor") }, as: :json

    assert_response :success
    assert_equal "Edited Vendor", @payment_advice.reload.payee_name
  end

  test "mail goes to every To, CC and BCC address and then locks the advice" do
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      post send_mail_payment_advice_path(@payment_advice),
        params: { payment_advice: advice_params(payee_email: "a@example.com, b@example.com", cc_emails: "c@example.com", bcc_emails: "d@example.com") },
        as: :json
    end

    assert_response :success
    mail = ActionMailer::Base.deliveries.last
    assert_equal %w[a@example.com b@example.com], mail.to
    assert_equal ["c@example.com"], mail.cc
    assert_equal ["d@example.com"], mail.bcc
    assert @payment_advice.reload.mail_sent?
    assert response.parsed_body.dig("payment_advice", "mail_sent_at").present?
  end

  test "a mailed advice cannot be edited or deleted, but can be mailed again unchanged" do
    @payment_advice.update_column(:mail_sent_at, 1.hour.ago)

    post payment_advices_path, params: { record_id: @payment_advice.id, payment_advice: advice_params(payee_name: "Changed") }, as: :json
    assert_response :unprocessable_entity
    assert_match "can no longer be edited", response.parsed_body["errors"].join

    # Delete is admin-only anyway; a mailed advice stays even then.
    assert_no_difference -> { PaymentAdviceRecord.count } do
      delete payment_advice_path(@payment_advice), as: :json
    end
    assert_not_equal 204, response.status

    post send_mail_payment_advice_path(@payment_advice), params: { payment_advice: advice_params(payee_name: "Changed") }, as: :json
    assert_response :success
    assert_equal "Original Vendor", @payment_advice.reload.payee_name
  end

  test "a wrong email in the lists is reported" do
    post payment_advices_path, params: { payment_advice: advice_params(advice_no: "PA-2026-950", cc_emails: "good@example.com, not-an-email") }, as: :json

    assert_response :unprocessable_entity
    assert_match "CC has an invalid email: not-an-email", response.parsed_body["errors"].join
  end

  test "emails used before are offered as suggestions" do
    @payment_advice.update!(cc_emails: "cc.person@example.com")

    get new_payment_advice_path
    assert_response :success
    assert_includes response.body, "cc.person@example.com"
    assert_includes response.body, "old.vendor@example.com"
  end

  private

  def advice_params(**overrides)
    {
      company_name: "Accounts Department", advice_no: @payment_advice.advice_no, payee_name: "Original Vendor",
      payee_email: "old.vendor@example.com", invoice_no: "INV-901", gross_amount: 1000, tds_amount: 50,
      other_deduction: 25, payment_mode: "NEFT"
    }.merge(overrides)
  end
end
