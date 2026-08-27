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
end
