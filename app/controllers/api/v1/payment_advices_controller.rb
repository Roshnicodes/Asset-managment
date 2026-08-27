module Api
  module V1
    class PaymentAdvicesController < ActionController::API
      before_action :authenticate_api_token!

      def create_and_send
        payment_advice = PaymentAdviceRecord.find_or_initialize_by(advice_no: payment_advice_params[:advice_no])
        payment_advice.assign_attributes(payment_advice_params)

        unless payment_advice.save
          render json: { errors: payment_advice.errors.full_messages }, status: :unprocessable_entity
          return
        end

        if payment_advice.payee_email.blank?
          render json: { error: "Recipient Email is required before sending mail." }, status: :unprocessable_entity
          return
        end

        unless PaymentAdviceMailer.payment_advice_delivery_configured?
          render json: { error: "SMTP is not configured. Please add SMTP_ADDRESS in server environment or Rails credentials." }, status: :unprocessable_entity
          return
        end

        PaymentAdviceMailer.with(payment_advice: payment_advice).payment_advice.deliver_now
        render json: {
          message: mail_success_message(payment_advice),
          payment_advice: payment_advice_payload(payment_advice)
        }, status: payment_advice.previously_new_record? ? :created : :ok
      rescue StandardError => e
        render json: { error: "Email could not be sent: #{e.message}" }, status: :bad_gateway
      end

      private

      def authenticate_api_token!
        token = ENV["PAYMENT_ADVICE_API_TOKEN"]
        return if token.blank? && Rails.env.local?

        if token.blank?
          render json: { error: "PAYMENT_ADVICE_API_TOKEN is not configured." }, status: :service_unavailable
          return
        end

        return if ActiveSupport::SecurityUtils.secure_compare(bearer_token, token)

        render json: { error: "Invalid API token." }, status: :unauthorized
      end

      def bearer_token
        request.authorization.to_s.match(/\ABearer (.+)\z/)&.[](1).to_s
      end

      def mail_success_message(payment_advice)
        if PaymentAdviceMailer.payment_advice_local_file_delivery? && !PaymentAdviceMailer.payment_advice_real_smtp_configured?
          "Mail was not sent to inbox. Local test copy saved at tmp/payment_advice_mails/#{payment_advice.payee_email}. Configure SMTP_ADDRESS, SMTP_USERNAME and SMTP_PASSWORD for real email."
        else
          "Payment advice sent to #{payment_advice.payee_email}."
        end
      end

      def payment_advice_params
        permitted_params = source_params.permit(
          :company_name, :advice_no, :payee_name, :payee_email, :recipient_email, :invoice_no, :invoice_date,
          :gross_amount, :tds_amount, :other_deduction, :payment_mode, :reference_no,
          :bank_name, :payment_date, :remarks
        )

        permitted_params[:payee_email] = permitted_params.delete(:recipient_email) if permitted_params[:recipient_email].present?
        permitted_params[:company_name] = "Accounts Department" if permitted_params[:company_name].blank?
        permitted_params[:advice_no] = PaymentAdviceRecord.next_advice_no if permitted_params[:advice_no].blank?

        permitted_params
      end

      def source_params
        params[:payment_advice].presence || params
      end

      def payment_advice_payload(advice)
        {
          id: advice.id,
          company_name: advice.company_name,
          advice_no: advice.advice_no,
          payee_name: advice.payee_name,
          payee_email: advice.payee_email,
          recipient_email: advice.payee_email,
          invoice_no: advice.invoice_no,
          invoice_date: advice.invoice_date,
          gross_amount: advice.gross_amount.to_s,
          tds_amount: advice.tds_amount.to_s,
          other_deduction: advice.other_deduction.to_s,
          net_amount: advice.net_amount.to_s,
          payment_mode: advice.payment_mode,
          reference_no: advice.reference_no,
          bank_name: advice.bank_name,
          payment_date: advice.payment_date,
          remarks: advice.remarks,
          created_at: advice.created_at.strftime("%d %b %Y")
        }
      end
    end
  end
end
