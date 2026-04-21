require "json"
require "net/http"
require "uri"

class QuotationVendorSmsGateway
  API_ENDPOINT = "https://sms.yoursmsbox.com/api/sendhttp.php".freeze
  DEFAULT_AUTHKEY = "37317061706c39353312".freeze
  ASA_DEFAULT_AUTHKEY = "3230666f72736131353261".freeze
  DEFAULT_SENDER = "PLOAPL".freeze
  DEFAULT_ROUTE = "2".freeze
  DEFAULT_COUNTRY = "0".freeze
  DEFAULT_UNICODE = "".freeze
  DEFAULT_RESPONSE_FORMAT = "json".freeze
  DEFAULT_LINK_TEMPLATE_ID = "1707177502703834106".freeze
  DEFAULT_OTP_TEMPLATE_ID = "1707177503375571501".freeze
  DEFAULT_PURCHASE_ORDER_LINK_TEMPLATE_ID = "1707177641235050439".freeze
  DEFAULT_PURCHASE_ORDER_OTP_TEMPLATE_ID = "1707177641235050439".freeze
  DEFAULT_BASE_URL = "http://127.0.0.1:3000".freeze
  ASA_LINK_TEMPLATE_ID = "1707177512006405172".freeze
  ASA_OTP_TEMPLATE_ID = "1707177528687356932".freeze
  ASA_PURCHASE_ORDER_LINK_TEMPLATE_ID = "1707177632997145777".freeze
  ASA_PURCHASE_ORDER_OTP_TEMPLATE_ID = "1707177633788078441".freeze
  ASA_SENDER = "ACTFSA".freeze

  def self.send_vendor_link(dispatch)
    config = sms_config_for(dispatch)
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: vendor_link_message(dispatch, config: config),
      template_id: config[:quotation_link_template_id],
      config: config
    )
  end

  def self.send_vendor_otp(dispatch, otp_record, purpose: :quotation)
    config = sms_config_for(dispatch)

    send_sms(
      mobile_no: dispatch.mobile_no,
      message: vendor_otp_message(dispatch, otp_record, config: config, purpose: purpose),
      template_id: otp_template_id_for(config, purpose: purpose),
      config: config
    )
  end

  def self.send_purchase_order_link(dispatch, proposal_vendor)
    config = sms_config_for(dispatch)
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: purchase_order_link_message(dispatch, proposal_vendor, config: config),
      template_id: config[:purchase_order_link_template_id],
      config: config
    )
  end

  def self.send_goods_receive_invoice_link(dispatch, invoice_request)
    config = sms_config_for(dispatch)
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: goods_receive_invoice_link_message(dispatch, invoice_request, config: config),
      template_id: config[:quotation_link_template_id],
      config: config
    )
  end

  def self.send_goods_receive_invoice_return_link(dispatch, invoice_request)
    config = sms_config_for(dispatch)
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: goods_receive_invoice_return_link_message(dispatch, invoice_request, config: config),
      template_id: config[:quotation_link_template_id],
      config: config
    )
  end

  def self.send_payment_advice(dispatch, invoice_request)
    config = sms_config_for(dispatch)
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: payment_advice_message(dispatch, invoice_request, config: config),
      template_id: config[:quotation_link_template_id],
      config: config
    )
  end

  def self.vendor_link_for(token)
    "#{base_url}/q/#{token}"
  end

  def self.purchase_order_link_for(token)
    "#{base_url}/p/#{token}"
  end

  def self.goods_receive_invoice_link_for(token)
    "#{base_url}/gr/#{token}"
  end

  def self.vendor_link_message(dispatch, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    quotation_reference = quotation_reference_for(dispatch)
    link = vendor_link_for(dispatch.quotation_proposal_vendor.qr_token)

    if config[:profile] == :asa
      "Dear #{vendor_name}, We kindly request you to accept the Quotation Proposal: #{quotation_reference}. Please submit the quotation through link: #{link}. - ACTION FOR SOCIAL ADVANCEMENT"
    else
      "Dear #{vendor_name}, PLOUGHMAN AGRO PRIVATE LIMITED requests you to review and accept the quotation proposal #{quotation_reference}. Please submit the quotation using the following link: #{link}."
    end
  end

  def self.vendor_otp_message(dispatch, otp_record, config:, purpose:)
    vendor_name = sms_vendor_name(dispatch, config: config)

    if purpose.to_sym == :purchase_order
      brand_name = config[:profile] == :asa ? "Action for social advancement" : "Ploughman Agro Private Limited (PAPL)"
      "Dear #{vendor_name}, #{otp_record.otp_code} is your one-time password to proceed with the purchase order process. Please do not share this OTP. - #{brand_name}"
    elsif config[:profile] == :asa
      "Dear #{vendor_name}, #{otp_record.otp_code} is your one-time password to proceed with the quotation process. Please do not share this OTP. - ACTION FOR SOCIAL ADVANCEMENT"
    else
      "Dear #{vendor_name}, #{otp_record.otp_code} is your one-time password to proceed further with the quotation process. Please do not share this OTP. - PLOUGHMAN AGRO PRIVATE LIMITED"
    end
  end

  def self.purchase_order_link_message(dispatch, proposal_vendor, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    purchase_order_reference = purchase_order_reference_for(dispatch, proposal_vendor)
    link = purchase_order_link_for(proposal_vendor.po_token)

    if config[:profile] == :asa
      "Dear #{vendor_name}, We kindly request you to accept the purchase order: #{purchase_order_reference}.through link: #{link}. - Action for social advancement (ASA)"
    else
      "Dear #{vendor_name}, We kindly request you to accept the purchase order: #{purchase_order_reference}.through link: #{link}. - Ploughman Agro Private Limited"
    end
  end

  def self.goods_receive_invoice_link_message(dispatch, invoice_request, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    quotation_reference = quotation_reference_for(dispatch)
    link = goods_receive_invoice_link_for(invoice_request.request_token)

    if config[:profile] == :asa
      "Dear #{vendor_name}, We kindly request you to accept the Quotation Proposal: #{quotation_reference}. Please submit the quotation through link: #{link}. - ACTION FOR SOCIAL ADVANCEMENT"
    else
      "Dear #{vendor_name}, PLOUGHMAN AGRO PRIVATE LIMITED requests you to review and accept the quotation proposal #{quotation_reference}. Please submit the quotation using the following link: #{link}."
    end
  end

  def self.goods_receive_invoice_return_link_message(dispatch, invoice_request, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    quotation_reference = quotation_reference_for(dispatch)
    link = goods_receive_invoice_link_for(invoice_request.request_token)

    if config[:profile] == :asa
      "Dear #{vendor_name}, Invoice for quotation #{quotation_reference} has been returned. Please re-upload the corrected invoice through link: #{link}. - ACTION FOR SOCIAL ADVANCEMENT"
    else
      "Dear #{vendor_name}, invoice for quotation #{quotation_reference} has been returned. Please re-upload the corrected invoice using this link: #{link}."
    end
  end

  def self.payment_advice_message(dispatch, invoice_request, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    quotation_reference = quotation_reference_for(dispatch)
    utr_date = invoice_request.utr_date&.strftime("%d-%m-%Y")
    bank_name = invoice_request.asa_bank_name.to_s.strip
    account_no = invoice_request.asa_account_no.to_s.strip

    if config[:profile] == :asa
      "Dear #{vendor_name}, payment advice for quotation #{quotation_reference} is ready. PDO No: #{invoice_request.pdo_no}, RFP No: #{invoice_request.rfp_no}, UTR No: #{invoice_request.utr_no}, UTR Date: #{utr_date}, Bank: #{bank_name}, A/C: #{account_no}. - ACTION FOR SOCIAL ADVANCEMENT"
    else
      "Dear #{vendor_name}, payment advice for quotation #{quotation_reference} is ready. PDO No: #{invoice_request.pdo_no}, RFP No: #{invoice_request.rfp_no}, UTR No: #{invoice_request.utr_no}, UTR Date: #{utr_date}, Bank: #{bank_name}, A/C: #{account_no}."
    end
  end

  def self.send_sms(mobile_no:, message:, template_id:, config:)
    delivery_result =
      begin
        perform_sms_request(
          mobile_no: mobile_no,
          message: message,
          template_id: template_id,
          config: config
        )
      rescue StandardError => error
        Rails.logger.error(
          "QuotationVendorSmsGateway primary request failed: #{error.class} #{error.message}"
        )
        {
          success: false,
          payload: nil,
          error_code: error.class.name,
          error_message: error.message.to_s
        }
      end

    if asa_sender_id_error?(delivery_result, config)
      Rails.logger.error(
        "QuotationVendorSmsGateway ASA sender rejected for sender=#{config[:sender]} template_id=#{template_id}. " \
        "Configure ASA_SMS_AUTHKEY and ASA_SMS_DLT_PE_ID for the ASA account."
      )
    end

    if retry_with_legacy_sender?(delivery_result, config)
      fallback_config = default_sms_config.merge(profile: :asa_legacy_fallback)
      fallback_template_id = fallback_template_id_for(config, template_id)
      Rails.logger.warn(
        "QuotationVendorSmsGateway retrying with legacy profile sender=#{fallback_config[:sender]} for mobile=#{normalize_mobile_no(mobile_no)} template_id=#{fallback_template_id}"
      )
      delivery_result =
        begin
          perform_sms_request(
            mobile_no: mobile_no,
            message: legacy_fallback_message(message, config),
            template_id: fallback_template_id,
            config: fallback_config
          )
        rescue StandardError => error
          Rails.logger.error(
            "QuotationVendorSmsGateway fallback request failed: #{error.class} #{error.message}"
          )
          {
            success: false,
            payload: nil,
            error_code: error.class.name,
            error_message: error.message.to_s
          }
        end
    end

    delivery_result[:success]
  end

  def self.perform_sms_request(mobile_no:, message:, template_id:, config:)
    sender = config[:sender]
    unicode = config[:unicode].to_s.strip == "1" ? "1" : unicode_flag_for(message).presence
    uri = URI(config[:api_endpoint])
    query_params = {
      authkey: config[:authkey],
      mobiles: normalize_mobile_no(mobile_no),
      message: message,
      sender: sender,
      route: config[:route],
      country: config[:country],
      DLT_TE_ID: template_id,
      response: DEFAULT_RESPONSE_FORMAT
    }
    query_params[:unicode] = unicode if unicode.present?
    query_params.merge!(pe_id_params(config))
    uri.query = URI.encode_www_form(query_params)

    Rails.logger.info(
      "QuotationVendorSmsGateway request profile=#{config[:profile]} mobile=#{normalize_mobile_no(mobile_no)} sender=#{sender} template_id=#{template_id} route=#{config[:route]} country=#{config[:country]}"
    )
    response = Net::HTTP.get_response(uri)
    Rails.logger.info("QuotationVendorSmsGateway response=#{response.code} body=#{response.body}")

    unless response.is_a?(Net::HTTPSuccess)
      return {
        success: false,
        payload: nil,
        error_code: response.code.to_s,
        error_message: response.body.to_s
      }
    end

    payload = parse_delivery_payload(response.body)
    {
      success: delivery_success?(payload),
      payload: payload,
      error_code: payload["Code"].to_s,
      error_message: payload["Description"].to_s
    }
  end

  def self.parse_delivery_payload(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError => error
    Rails.logger.error("QuotationVendorSmsGateway invalid JSON response: #{error.message} body=#{body}")
    {}
  end

  def self.delivery_success?(payload)
    payload["Status"] == "Success" && payload["Code"] == "000"
  end

  def self.retry_with_legacy_sender?(delivery_result, config)
    return false unless config[:profile] == :asa

    error_message = delivery_result[:error_message].to_s.downcase

    error_message.include?("connection reset by peer") ||
      error_message.include?("ssl_connect")
  end

  def self.asa_sender_id_error?(delivery_result, config)
    return false unless config[:profile] == :asa

    error_message = delivery_result[:error_message].to_s.downcase
    delivery_result[:error_code] == "004" &&
      (error_message.include?("sender-id") || error_message.include?("sender id"))
  end

  def self.base_url
    configured_base_url.presence || DEFAULT_BASE_URL
  end

  def self.quotation_reference_for(dispatch)
    quotation_proposal = dispatch.try(:quotation_proposal)

    return quotation_proposal.reference_number if quotation_proposal.respond_to?(:reference_number) && quotation_proposal.reference_number.present?
    return quotation_proposal.proposal_number if quotation_proposal.respond_to?(:proposal_number) && quotation_proposal.proposal_number.present?
    return quotation_proposal.id if quotation_proposal.respond_to?(:id) && quotation_proposal.id.present?

    dispatch.quotation_proposal_id
  end

  def self.purchase_order_reference_for(dispatch, proposal_vendor)
    quotation_proposal = proposal_vendor.try(:quotation_proposal) || dispatch.try(:quotation_proposal)
    proposal_id = quotation_proposal.try(:id).presence || dispatch.try(:quotation_proposal_id).presence
    return quotation_reference_for(dispatch) if proposal_id.blank?

    stakeholder_code = [
      quotation_proposal&.theme&.stakeholder_category&.name,
      dispatch.try(:stakeholder_category)&.name,
      dispatch.try(:vendor_registration)&.stakeholder_category&.name,
      proposal_vendor.try(:vendor_registration)&.stakeholder_category&.name
    ].compact.map { |value| value.to_s.strip }.find(&:present?).presence || "ASA"

    "#{stakeholder_code}/PO/#{proposal_id}/#{purchase_order_year_label}"
  end

  def self.purchase_order_year_label
    current_year = Date.current.year
    next_year_short = (current_year + 1).to_s.last(2)
    "#{current_year}-#{next_year_short}"
  end

  def self.normalize_mobile_no(mobile_no)
    digits = mobile_no.to_s.gsub(/\D+/, "")
    digits = digits.delete_prefix("0") if digits.length == 11 && digits.start_with?("0")
    digits = digits.delete_prefix("91") if digits.length == 12 && digits.start_with?("91")
    digits
  end

  def self.unicode_flag_for(message)
    return "1" unless message.to_s.ascii_only?

    DEFAULT_UNICODE
  end

  def self.pe_id_params(config)
    pe_id = config[:pe_id].to_s.strip
    return {} if pe_id.blank?

    {
      PE_ID: pe_id,
      DLT_PE_ID: pe_id
    }
  end

  def self.configured_base_url
    env_base_url = ENV["APP_BASE_URL"].to_s.strip
    return env_base_url.chomp("/") if env_base_url.present?

    default_options = Rails.application.routes.default_url_options
    host = default_options[:host].to_s.strip
    return if host.blank?

    protocol = default_options[:protocol].presence || "http"
    port = default_options[:port].presence
    [ "#{protocol}://#{host}", port ].compact.join(":").chomp("/")
  end

  def self.sms_config_for(dispatch)
    stakeholder_name = stakeholder_name_for(dispatch)

    if asa_stakeholder?(stakeholder_name)
      asa_sms_config
    else
      default_sms_config
    end
  end

  def self.asa_sms_config
    {
      profile: :asa,
      api_endpoint: ENV.fetch("ASA_SMS_API_ENDPOINT", ENV.fetch("SMS_API_ENDPOINT", API_ENDPOINT)),
      authkey: ENV.fetch("ASA_SMS_AUTHKEY", ASA_DEFAULT_AUTHKEY),
      sender: ENV.fetch("ASA_SMS_SENDER", ASA_SENDER),
      route: ENV.fetch("ASA_SMS_ROUTE", ENV.fetch("SMS_ROUTE", DEFAULT_ROUTE)),
      country: ENV.fetch("ASA_SMS_COUNTRY", ENV.fetch("SMS_COUNTRY", DEFAULT_COUNTRY)),
      unicode: ENV.fetch("ASA_SMS_UNICODE", ENV.fetch("SMS_UNICODE", DEFAULT_UNICODE)),
      pe_id: ENV.fetch("ASA_SMS_DLT_PE_ID", ENV.fetch("SMS_DLT_PE_ID", "")),
      quotation_link_template_id: ENV.fetch("ASA_SMS_LINK_DLT_TEMPLATE_ID", ASA_LINK_TEMPLATE_ID),
      quotation_otp_template_id: ENV.fetch("ASA_SMS_OTP_DLT_TEMPLATE_ID", ASA_OTP_TEMPLATE_ID),
      purchase_order_link_template_id: ENV.fetch("ASA_SMS_PURCHASE_ORDER_LINK_DLT_TEMPLATE_ID", ASA_PURCHASE_ORDER_LINK_TEMPLATE_ID),
      purchase_order_otp_template_id: ENV.fetch("ASA_SMS_PURCHASE_ORDER_OTP_DLT_TEMPLATE_ID", ASA_PURCHASE_ORDER_OTP_TEMPLATE_ID)
    }
  end

  def self.default_sms_config
    {
      profile: :default,
      api_endpoint: ENV.fetch("SMS_API_ENDPOINT", API_ENDPOINT),
      authkey: ENV.fetch("SMS_AUTHKEY", DEFAULT_AUTHKEY),
      sender: ENV.fetch("SMS_SENDER", DEFAULT_SENDER),
      route: ENV.fetch("SMS_ROUTE", DEFAULT_ROUTE),
      country: ENV.fetch("SMS_COUNTRY", DEFAULT_COUNTRY),
      unicode: ENV.fetch("SMS_UNICODE", DEFAULT_UNICODE),
      pe_id: ENV.fetch("SMS_DLT_PE_ID", ""),
      quotation_link_template_id: ENV.fetch("SMS_LINK_DLT_TEMPLATE_ID", DEFAULT_LINK_TEMPLATE_ID),
      quotation_otp_template_id: ENV.fetch("SMS_OTP_DLT_TEMPLATE_ID", DEFAULT_OTP_TEMPLATE_ID),
      purchase_order_link_template_id: ENV.fetch("SMS_PURCHASE_ORDER_LINK_DLT_TEMPLATE_ID", DEFAULT_PURCHASE_ORDER_LINK_TEMPLATE_ID),
      purchase_order_otp_template_id: ENV.fetch("SMS_PURCHASE_ORDER_OTP_DLT_TEMPLATE_ID", DEFAULT_PURCHASE_ORDER_OTP_TEMPLATE_ID)
    }
  end

  def self.otp_template_id_for(config, purpose:)
    purpose.to_sym == :purchase_order ? config[:purchase_order_otp_template_id] : config[:quotation_otp_template_id]
  end

  def self.fallback_template_id_for(config, template_id)
    if template_id.to_s == config[:quotation_link_template_id].to_s
      default_sms_config[:quotation_link_template_id]
    elsif template_id.to_s == config[:purchase_order_link_template_id].to_s
      default_sms_config[:purchase_order_link_template_id]
    elsif template_id.to_s == config[:purchase_order_otp_template_id].to_s
      default_sms_config[:purchase_order_otp_template_id]
    else
      default_sms_config[:quotation_otp_template_id]
    end
  end

  def self.legacy_fallback_message(message, config)
    return message unless config[:profile] == :asa

    message
      .gsub("Action for social advancement (ASA)", "Ploughman Agro Private Limited")
      .gsub("Action for social advancement", "Ploughman Agro Private Limited (PAPL)")
      .gsub("proceed with the quotation process", "proceed further with the quotation process")
      .gsub("ACTION FOR SOCIAL ADVANCEMENT", "PLOUGHMAN AGRO PRIVATE LIMITED")
      .gsub("We kindly request you to accept the Quotation Proposal", "PLOUGHMAN AGRO PRIVATE LIMITED requests you to review and accept the quotation proposal")
      .gsub("Please submit the quotation through link:", "Please submit the quotation using this link")
  end

  def self.sms_vendor_name(dispatch, config:)
    vendor_name = dispatch.vendor_name.to_s.strip.presence || "Vendor"
    return vendor_name if config[:profile] != :asa

    vendor_name.upcase
  end

  def self.stakeholder_name_for(dispatch)
    [
      dispatch.quotation_proposal&.theme&.stakeholder_category&.name,
      dispatch.stakeholder_category&.name,
      dispatch.vendor_registration&.stakeholder_category&.name,
    ].compact.map { |value| value.to_s.strip }.find(&:present?).to_s.upcase
  end

  def self.asa_stakeholder?(stakeholder_name)
    normalized_name = stakeholder_name.to_s.upcase
    normalized_name == "ASA" || normalized_name.include?("ACTION FOR SOCIAL ADVANCEMENT")
    end
end
