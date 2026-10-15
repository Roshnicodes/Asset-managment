class PaymentAdvicesController < ApplicationController
  before_action :require_payment_advice_studio_access!
  before_action :set_payment_advice, only: %i[destroy send_mail]

  def new
    Bank.ensure_default!
    @banks = Bank.ordered.map { |bank| { id: bank.id, name: bank.name } }
    @payment_advices = PaymentAdviceRecord.recent.limit(50).map { |advice| payment_advice_payload(advice) }
    @next_advice_no = PaymentAdviceRecord.next_advice_no
    @used_emails = PaymentAdviceRecord.used_emails
  end

  # A saved advice is updated by its id; a new one never overwrites another
  # advice that already has the same number.
  def create
    payment_advice = params[:record_id].present? ? PaymentAdviceRecord.find(params[:record_id]) : PaymentAdviceRecord.new
    payment_advice.assign_attributes(payment_advice_params)

    if payment_advice.save
      render json: payment_advice_payload(payment_advice), status: payment_advice.previously_new_record? ? :created : :ok
    else
      render json: { errors: payment_advice.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    if @payment_advice.mail_sent?
      render json: { error: "This payment advice was already mailed and cannot be deleted." }, status: :unprocessable_entity
      return
    end

    @payment_advice.destroy

    head :no_content
  end

  def send_mail
    # A mailed advice is final: it can be sent again, but not changed.
    return unless @payment_advice.mail_sent? || apply_payment_advice_params_for_mail

    if @payment_advice.payee_email.blank?
      render json: { error: "Recipient Email is required before sending mail." }, status: :unprocessable_entity
      return
    end

    # Without SMTP the mail goes out through the ASA mail service.
    if PaymentAdviceMailRelay.enabled?
      begin
        PaymentAdviceMailRelay.deliver!(@payment_advice)
      rescue PaymentAdviceMailRelay::PartialDeliveryError => error
        mark_mail_sent!
        render json: { error: error.message, payment_advice: payment_advice_payload(@payment_advice) }, status: :bad_gateway
        return
      end
      mark_mail_sent!
      render json: { message: "Payment advice sent to #{recipients_label}.", payment_advice: payment_advice_payload(@payment_advice) }
      return
    end

    unless PaymentAdviceMailer.payment_advice_delivery_configured?
      render json: { error: "SMTP is not configured. Please add SMTP_ADDRESS in server environment or Rails credentials." }, status: :unprocessable_entity
      return
    end

    PaymentAdviceMailer.with(payment_advice: @payment_advice).payment_advice.deliver_now
    mark_mail_sent!
    render json: { message: mail_success_message, payment_advice: payment_advice_payload(@payment_advice) }
  rescue StandardError => e
    render json: { error: "Email could not be sent: #{e.message}" }, status: :bad_gateway
  end

  private

  def set_payment_advice
    @payment_advice = PaymentAdviceRecord.find(params[:id])
  end

  def apply_payment_advice_params_for_mail
    return true unless params[:payment_advice].present?

    @payment_advice.assign_attributes(payment_advice_params)
    return true if @payment_advice.save

    render json: { errors: @payment_advice.errors.full_messages }, status: :unprocessable_entity
    false
  end

  def mark_mail_sent!
    @payment_advice.update_column(:mail_sent_at, Time.current)
  end

  def recipients_label
    [@payment_advice.payee_email, @payment_advice.cc_emails.presence && "CC: #{@payment_advice.cc_emails}",
     @payment_advice.bcc_emails.presence && "BCC: #{@payment_advice.bcc_emails}"].compact.join(" | ")
  end

  def mail_success_message
    if PaymentAdviceMailer.payment_advice_local_file_delivery? && !PaymentAdviceMailer.payment_advice_real_smtp_configured?
      "Mail was not sent to inbox. Local test copy saved at tmp/payment_advice_mails/#{@payment_advice.payee_email}. Configure SMTP_ADDRESS, SMTP_USERNAME and SMTP_PASSWORD for real email."
    else
      "Payment advice sent to #{recipients_label}."
    end
  end

  def payment_advice_params
    params.expect(payment_advice: [
      :company_name, :advice_no, :payee_name, :payee_email, :cc_emails, :bcc_emails, :invoice_no, :invoice_date,
      :gross_amount, :tds_amount, :other_deduction, :payment_mode, :reference_no,
      :bank_name, :payment_date, :remarks
    ])
  end

  def payment_advice_payload(advice)
    {
      id: advice.id,
      company_name: advice.company_name,
      advice_no: advice.advice_no,
      payee_name: advice.payee_name,
      payee_email: advice.payee_email,
      cc_emails: advice.cc_emails,
      bcc_emails: advice.bcc_emails,
      mail_sent_at: advice.mail_sent_at&.in_time_zone("Asia/Kolkata")&.strftime("%d %b %Y, %I:%M %p"),
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
