class PaymentAdviceMailer < ApplicationMailer
  def payment_advice
    @payment_advice = params[:payment_advice]

    mail(
      to: @payment_advice.payee_email,
      from: payment_advice_sender,
      subject: "Payment Advice #{@payment_advice.advice_no}"
    )
  end

  private

  def payment_advice_sender
    ENV["SMTP_FROM"].presence ||
      ENV["MAILER_SENDER"].presence ||
      Rails.application.credentials.dig(:smtp, :from).presence ||
      "no-reply@example.com"
  end
end
