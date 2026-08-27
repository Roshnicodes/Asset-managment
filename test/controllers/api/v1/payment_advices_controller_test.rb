require "test_helper"

module Api
  module V1
    class PaymentAdvicesControllerTest < ActionDispatch::IntegrationTest
      setup do
        ActionMailer::Base.deliveries.clear
      end

      test "create and send accepts recipient email alias" do
        assert_difference -> { PaymentAdviceRecord.count }, 1 do
          assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
            post api_v1_payment_advices_send_mail_path,
              params: {
                payment_advice: {
                  company_name: "Test Company",
                  advice_no: "PA-API-901",
                  payee_name: "Demo Vendor",
                  recipient_email: "r.tiwari@asabhopal.org",
                  invoice_no: "INV-001",
                  invoice_date: "2026-08-24",
                  gross_amount: 1000,
                  tds_amount: 100,
                  other_deduction: 0,
                  payment_mode: "NEFT",
                  reference_no: "UTR123",
                  bank_name: "HDFC Bank",
                  payment_date: "2026-08-24"
                }
              },
              as: :json
          end
        end

        assert_response :created
        assert_equal ["r.tiwari@asabhopal.org"], ActionMailer::Base.deliveries.last.to
        assert_equal "r.tiwari@asabhopal.org", PaymentAdviceRecord.find_by!(advice_no: "PA-API-901").payee_email
      end
    end
  end
end
