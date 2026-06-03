require "json"
require "net/http"
require "uri"

class QuotationVendorSmsGateway
  API_ENDPOINT = "https://sms.yoursmsbox.com/api/sendhttp.php".freeze
  DEFAULT_AUTHKEY = "37317061706c39353312".freeze
  ASA_DEFAULT_AUTHKEY = "3230666f72736131353261".freeze
  DEFAULT_SENDER = "PLOAPL".freeze
  DEFAULT_ROUTE = "2".freeze
  DEFAULT_COUNTRY = "91".freeze
  DEFAULT_UNICODE = "".freeze
  DEFAULT_RESPONSE_FORMAT = "json".freeze
  DEFAULT_LINK_TEMPLATE_ID = "1707177502703834106".freeze
  DEFAULT_OTP_TEMPLATE_ID = "1707177503375571501".freeze
  DEFAULT_PURCHASE_ORDER_LINK_TEMPLATE_ID = "1707177641694704075".freeze
  DEFAULT_PURCHASE_ORDER_OTP_TEMPLATE_ID = "1707177641235050439".freeze
  DEFAULT_INVOICE_LINK_TEMPLATE_ID = "1707177648937573645".freeze
  DEFAULT_INVOICE_RETURN_LINK_TEMPLATE_ID = "1707177650435445886".freeze
  DEFAULT_INVOICE_OTP_TEMPLATE_ID = "1707177675366996869".freeze
  DEFAULT_VENDOR_REGISTRATION_LINK_TEMPLATE_ID = "1707177944223861381".freeze
  DEFAULT_VENDOR_REGISTRATION_OTP_TEMPLATE_ID = "1707177944234142889".freeze
  DEFAULT_VENDOR_REGISTRATION_BASE_URL = "http://apurti.ploughmanagro.com".freeze
  DEFAULT_VENDOR_REGISTRATION_CTA_URL = "http://apurti.ploughmanagro.com/vr?".freeze
  DEVELOPMENT_BASE_URL = "http://127.0.0.1:3000".freeze
  ASA_LINK_TEMPLATE_ID = "1707177512006405172".freeze
  ASA_OTP_TEMPLATE_ID = "1707177528687356932".freeze
  ASA_PURCHASE_ORDER_LINK_TEMPLATE_ID = "1707177632997145777".freeze
  ASA_PURCHASE_ORDER_OTP_TEMPLATE_ID = "1707177633788078441".freeze
  ASA_INVOICE_LINK_TEMPLATE_ID = "1707177674942135728".freeze
  ASA_INVOICE_RETURN_LINK_TEMPLATE_ID = "1707177674947419559".freeze
  ASA_INVOICE_OTP_TEMPLATE_ID = "1707177675358503792".freeze
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
      template_id: config[:invoice_link_template_id],
      config: config
    )
  end

  def self.send_goods_receive_invoice_return_link(dispatch, invoice_request)
    config = sms_config_for(dispatch)
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: goods_receive_invoice_return_link_message(dispatch, invoice_request, config: config),
      template_id: config[:invoice_return_link_template_id],
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

  def self.send_vendor_registration_link(invitation)
    config = vendor_registration_sms_config
    send_sms(
      mobile_no: invitation.mobile_no,
      message: vendor_registration_link_message(invitation, config: config),
      template_id: config[:vendor_registration_link_template_id],
      config: config
    )
  end

  def self.send_vendor_registration_otp(invitation)
    config = vendor_registration_sms_config
    send_sms(
      mobile_no: invitation.mobile_no,
      message: vendor_registration_otp_message(invitation, config: config),
      template_id: config[:vendor_registration_otp_template_id],
      config: config
    )
  end

  def self.vendor_link_for(token)
    "#{base_url}/q/#{token}"
  end

  def self.vendor_registration_link_for(token, config: nil)
    "#{base_url(config: config)}/vr/#{token}"
  end

  def self.vendor_registration_start_link_for(config: nil)
    configured_url = base_url(config: config)
    return "#{configured_url}/vr" if local_runtime_environment?

    host = URI.parse(configured_url).host
    host = configured_url.sub(%r{\Ahttps?://}, "").split("/").first if host.blank?
    "#{host}/vr"
  rescue URI::InvalidURIError
    base_url(config: config).sub(%r{\Ahttps?://}, "").chomp("/") + "/vr"
  end

  def self.vendor_registration_sms_link_for_config(token, config:)
    cta_url = vendor_registration_sms_cta_base_url(config: config)
    return "#{cta_url}#{token}" if cta_url.end_with?("?")
    return "#{cta_url}t=#{token}" if cta_url.end_with?("&")

    "#{cta_url}/#{token}"
  end

  def self.vendor_link_for_config(token, config:)
    "#{base_url(config: config)}/q/#{token}"
  end

  def self.vendor_sms_link_for_config(token, config:)
    "#{base_url(config: config)}/q?t=#{token}"
  end

  def self.asa_vendor_link_for_config(dispatch, config:)
    proposal_vendor_id = dispatch.quotation_proposal_vendor.try(:id).presence
    quotation_proposal_id = quotation_proposal_id_for_link(dispatch)
    return vendor_sms_link_for_config(dispatch.quotation_proposal_vendor.qr_token, config: config) if proposal_vendor_id.blank? || quotation_proposal_id.blank?

    "#{base_url(config: config)}/xyz?v=#{proposal_vendor_id}&qp=#{quotation_proposal_id}"
  end

  def self.purchase_order_link_for(token)
    "#{base_url}/p/#{token}"
  end

  def self.purchase_order_link_for_config(token, config:)
    "#{base_url(config: config)}/p/#{token}"
  end

  def self.purchase_order_sms_link_for_config(token, config:)
    "#{base_url(config: config)}/p?t=#{token}"
  end

  def self.goods_receive_invoice_link_for(token)
    "#{base_url}/gr/#{token}"
  end

  def self.goods_receive_invoice_link_for_config(token, config:)
    "#{base_url(config: config)}/gr/#{token}"
  end

  def self.goods_receive_invoice_sms_link_for_config(token, config:)
    purchase_order_sms_link_for_config(token, config: config)
  end

  def self.vendor_link_message(dispatch, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    quotation_reference = quotation_reference_for(dispatch)
    link =
      if config[:profile] == :asa
        asa_vendor_link_for_config(dispatch, config: config)
      else
        vendor_sms_link_for_config(dispatch.quotation_proposal_vendor.qr_token, config: config)
      end

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
    elsif purpose.to_sym == :invoice
      brand_name = config[:profile] == :asa ? "Action for social advancement" : "Ploughman Agro Private Limited (PAPL)"
      "Dear #{vendor_name}, #{otp_record.otp_code} is your one-time password to proceed with the invoice for purchase order process. Please do not share this OTP. - #{brand_name}"
    elsif config[:profile] == :asa
      "Dear #{vendor_name}, #{otp_record.otp_code} is your one-time password to proceed with the quotation process. Please do not share this OTP. - ACTION FOR SOCIAL ADVANCEMENT"
    else
      "Dear #{vendor_name}, #{otp_record.otp_code} is your one-time password to proceed further with the quotation process. Please do not share this OTP. - PLOUGHMAN AGRO PRIVATE LIMITED"
    end
  end

  def self.purchase_order_link_message(dispatch, proposal_vendor, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    purchase_order_reference = purchase_order_reference_for(dispatch, proposal_vendor)
    link = purchase_order_sms_link_for_config(proposal_vendor.po_token, config: config)

    if config[:profile] == :asa
      "Dear #{vendor_name}, We kindly request you to accept the purchase order: #{purchase_order_reference}.through link: #{link}. - Action for social advancement (ASA)"
    else
      "Dear #{vendor_name}, We kindly request you to accept the purchase order: #{purchase_order_reference}.through link: #{link}. - Ploughman Agro Private Limited"
    end
  end

  def self.goods_receive_invoice_link_message(dispatch, invoice_request, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    purchase_order_reference = purchase_order_reference_for(dispatch, invoice_request.quotation_proposal_vendor)
    link = goods_receive_invoice_sms_link_for_config(invoice_request.request_token, config: config)

    if config[:profile] == :asa
      "Dear #{vendor_name}, We kindly request you to upload the invoice for the purchase order: #{purchase_order_reference}.through link: #{link}. - Action For Social Advancement(ASA)"
    else
      "Dear #{vendor_name}, We kindly request you to upload the invoice for the purchase order: #{purchase_order_reference}.through link: #{link}. - Ploughman Agro Private Limited (PAPL)"
    end
  end

  def self.goods_receive_invoice_return_link_message(dispatch, invoice_request, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    purchase_order_reference = purchase_order_reference_for(dispatch, invoice_request.quotation_proposal_vendor)
    link = goods_receive_invoice_sms_link_for_config(invoice_request.request_token, config: config)

    if config[:profile] == :asa
      "Dear #{vendor_name}, Your invoice has been rejected. Please upload a revised invoice for PO: #{purchase_order_reference} using the link below:#{link}.-Action For Social Advancement (ASA)"
    else
      "Dear #{vendor_name}, Your invoice has been rejected. Please upload a revised invoice for PO: #{purchase_order_reference} using the link below: #{link}. - Ploughman Agro Private Limited (PAPL)"
    end
  end

  def self.payment_advice_message(dispatch, invoice_request, config:)
    vendor_name = sms_vendor_name(dispatch, config: config)
    quotation_reference = quotation_reference_for(dispatch)
    transaction_type = invoice_request.payment_transaction_type.to_s.strip
    transaction_no = invoice_request.payment_transaction_no.to_s.strip
    transaction_date = invoice_request.payment_transaction_date&.strftime("%d-%m-%Y")

    if config[:profile] == :asa
      "Dear #{vendor_name}, payment update for quotation #{quotation_reference} is ready. PDO No: #{invoice_request.pdo_no}, RFP No: #{invoice_request.rfp_no}, Transaction Type: #{transaction_type}, Transaction No: #{transaction_no}, Transaction Date: #{transaction_date}. - ACTION FOR SOCIAL ADVANCEMENT"
    else
      "Dear #{vendor_name}, payment update for quotation #{quotation_reference} is ready. PDO No: #{invoice_request.pdo_no}, RFP No: #{invoice_request.rfp_no}, Transaction Type: #{transaction_type}, Transaction No: #{transaction_no}, Transaction Date: #{transaction_date}."
    end
  end

  def self.vendor_registration_link_message(invitation, config:)
    "Dear Vendor, Please registration using the link below: #{vendor_registration_sms_link_for_config(invitation.token, config: config)} Ploughman Agro Private Limited (PAPL)"
  end

  def self.vendor_registration_otp_message(invitation, config:)
    "Dear Vendor, #{invitation.otp_code} is your OTP to proceed with vendor registration. Please do not share this OTP with anyone. Ploughman Agro Private Limited (PAPL)"
  end

  def self.send_sms(mobile_no:, message:, template_id:, config:)
    clear_last_error_message
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

    set_last_error_message(delivery_result[:error_message]) unless delivery_result[:success]
    delivery_result[:success]
  end

  def self.perform_sms_request(mobile_no:, message:, template_id:, config:)
    normalized_mobile_no = normalize_mobile_no(mobile_no)
    unless valid_indian_mobile_no?(normalized_mobile_no)
      error_message = "SMS mobile number #{mobile_no.to_s.strip.presence || "(blank)"} is invalid. Enter a 10-digit Indian mobile number starting with 6, 7, 8, or 9."
      Rails.logger.error("QuotationVendorSmsGateway mobile validation failed: #{error_message}")
      return {
        success: false,
        payload: nil,
        error_code: "SMS_INVALID_MOBILE_NUMBER",
        error_message: error_message
      }
    end

    if (validation_error = sms_url_validation_error(message, config))
      Rails.logger.error("QuotationVendorSmsGateway URL validation failed: #{validation_error}")
      return {
        success: false,
        payload: nil,
        error_code: "SMS_URL_CONFIGURATION_ERROR",
        error_message: validation_error
      }
    end

    sender = config[:sender]
    unicode = config[:unicode].to_s.strip == "1" ? "1" : unicode_flag_for(message).presence
    uri = URI(config[:api_endpoint])
    query_params = {
      authkey: config[:authkey],
      mobiles: normalized_mobile_no,
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
      "QuotationVendorSmsGateway request profile=#{config[:profile]} mobile=#{normalized_mobile_no} sender=#{sender} template_id=#{template_id} route=#{config[:route]} country=#{config[:country]} urls=#{sms_message_urls(message).join(",")}"
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
      error_message: delivery_error_message(payload)
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

  def self.delivery_error_message(payload)
    description = payload["Description"].to_s
    code = payload["Code"].to_s
    normalized_description = description.downcase

    if normalized_description.include?("invaliddestinationreference")
      return "SMS provider rejected the destination reference (#{description.presence || code}). Verify the mobile number and that the SMS CTA URL is whitelisted for this template/header."
    end

    description
  end

  def self.last_error_message
    Thread.current[:quotation_vendor_sms_gateway_last_error_message]
  end

  def self.clear_last_error_message
    Thread.current[:quotation_vendor_sms_gateway_last_error_message] = nil
  end

  def self.set_last_error_message(message)
    Thread.current[:quotation_vendor_sms_gateway_last_error_message] = message.to_s.presence
  end

  def self.sms_message_urls(message)
    URI.extract(message.to_s, ["http", "https"])
  end

  def self.sms_url_validation_error(message, config)
    urls = sms_message_urls(message)
    return if urls.blank?

    parsed_urls = urls.filter_map do |url|
      URI.parse(url)
    rescue URI::InvalidURIError
      nil
    end

    invalid_url = parsed_urls.find { |url| placeholder_sms_host?(url.host) }
    if invalid_url.present?
      return "SMS link is using #{invalid_url.host}. Configure ASA_APP_BASE_URL/SMS_APP_BASE_URL/APP_BASE_URL with the approved production host before sending link SMS."
    end

    allowed_hosts = allowed_sms_url_hosts(config)
    return if allowed_hosts.blank?

    invalid_host = parsed_urls.map { |url| url.host.to_s.downcase }.find { |host| host.present? && !allowed_hosts.include?(host) }
    return if invalid_host.blank?

    "SMS link host #{invalid_host} is not in the approved SMS URL hosts (#{allowed_hosts.join(", ")}). Update ASA_APP_BASE_URL/SMS_APP_BASE_URL or the DLT CTA whitelist."
  end

  def self.placeholder_sms_host?(host)
    return false if local_runtime_environment?

    normalized_host = host.to_s.downcase
    normalized_host.blank? ||
      normalized_host == "example.com" ||
      normalized_host == "localhost" ||
      normalized_host == "127.0.0.1" ||
      normalized_host == "0.0.0.0"
  end

  def self.allowed_sms_url_hosts(config)
    env_value =
      case config[:profile]
      when :asa
        ENV["ASA_SMS_ALLOWED_URL_HOSTS"].presence || ENV["SMS_ALLOWED_URL_HOSTS"]
      else
        ENV["SMS_ALLOWED_URL_HOSTS"]
      end

    env_value.to_s.split(",").map { |host| host.strip.downcase }.reject(&:blank?)
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

  def self.base_url(config: nil)
    configured_base_url(config: config).presence || (local_runtime_environment? ? DEVELOPMENT_BASE_URL : DEFAULT_VENDOR_REGISTRATION_BASE_URL)
  end

  def self.quotation_reference_for(dispatch)
    quotation_proposal = dispatch.try(:quotation_proposal)

    return quotation_proposal.reference_number if quotation_proposal.respond_to?(:reference_number) && quotation_proposal.reference_number.present?
    return quotation_proposal.proposal_number if quotation_proposal.respond_to?(:proposal_number) && quotation_proposal.proposal_number.present?
    return quotation_proposal.id if quotation_proposal.respond_to?(:id) && quotation_proposal.id.present?

    dispatch.quotation_proposal_id
  end

  def self.quotation_proposal_id_for_link(dispatch)
    quotation_proposal = dispatch.try(:quotation_proposal)
    return quotation_proposal.id if quotation_proposal.respond_to?(:id) && quotation_proposal.id.present?

    dispatch.try(:quotation_proposal_id)
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

  def self.valid_indian_mobile_no?(mobile_no)
    mobile_no.to_s.match?(/\A[6-9]\d{9}\z/)
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

  def self.configured_base_url(config: nil)
    env_base_url = profile_base_url(config).presence || ENV["APP_BASE_URL"].to_s.strip
    return env_base_url.chomp("/") if env_base_url.present?

    default_options = normalized_url_options(Rails.application.routes.default_url_options)
    default_options = normalized_url_options(Rails.application.config.action_mailer.default_url_options) if default_options[:host].blank?

    if default_options[:host].blank? && defined?(ActionMailer::Base)
      default_options = normalized_url_options(ActionMailer::Base.default_url_options)
    end

    host = default_options[:host].to_s.strip
    return if host.blank?
    return if !local_runtime_environment? && host.casecmp("example.com").zero?

    protocol = default_options[:protocol].presence || "http"
    port = default_options[:port].presence
    [ "#{protocol}://#{host}", port ].compact.join(":").chomp("/")
  end

  def self.profile_base_url(config)
    case config&.fetch(:profile, nil)
    when :asa
      ENV["ASA_APP_BASE_URL"].to_s.strip
    when :vendor_registration
      vendor_registration_profile_base_url
    when :default, :asa_legacy_fallback
      ENV["SMS_APP_BASE_URL"].to_s.strip
    else
      ""
    end
  end

  def self.normalized_url_options(options)
    options.to_h.symbolize_keys
  rescue NoMethodError
    {}
  end

  def self.vendor_registration_profile_base_url
    if local_runtime_environment?
      ENV["VENDOR_REGISTRATION_APP_BASE_URL"].presence ||
        ENV["APP_BASE_URL"].presence ||
        DEVELOPMENT_BASE_URL
    else
      ENV["VENDOR_REGISTRATION_APP_BASE_URL"].presence ||
        ENV["SMS_APP_BASE_URL"].presence ||
        ENV["PAPL_APP_BASE_URL"].presence ||
        DEFAULT_VENDOR_REGISTRATION_BASE_URL
    end
  end

  def self.default_vendor_registration_cta_url(config:)
    return DEFAULT_VENDOR_REGISTRATION_CTA_URL unless local_runtime_environment?

    "#{base_url(config: config)}/vr?"
  end

  def self.vendor_registration_sms_cta_base_url(config:)
    cta_url = ENV["SMS_VENDOR_REGISTRATION_CTA_URL"].presence || default_vendor_registration_cta_url(config: config)
    cta_url.end_with?("?") || cta_url.end_with?("&") ? cta_url : cta_url.chomp("/")
  end

  def self.local_runtime_environment?
    Rails.env.development? || Rails.env.test?
  end

  def self.sms_config_for(dispatch)
    stakeholder_name = stakeholder_name_for(dispatch)

    if asa_stakeholder?(stakeholder_name)
      asa_sms_config
    else
      default_sms_config
    end
  end

  def self.vendor_registration_sms_config
    default_sms_config.merge(
      profile: :vendor_registration,
      vendor_registration_link_template_id: ENV.fetch("SMS_VENDOR_REGISTRATION_LINK_DLT_TEMPLATE_ID", DEFAULT_VENDOR_REGISTRATION_LINK_TEMPLATE_ID),
      vendor_registration_otp_template_id: ENV.fetch("SMS_VENDOR_REGISTRATION_OTP_DLT_TEMPLATE_ID", DEFAULT_VENDOR_REGISTRATION_OTP_TEMPLATE_ID)
    )
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
      purchase_order_otp_template_id: ENV.fetch("ASA_SMS_PURCHASE_ORDER_OTP_DLT_TEMPLATE_ID", ASA_PURCHASE_ORDER_OTP_TEMPLATE_ID),
      invoice_link_template_id: ENV.fetch("ASA_SMS_INVOICE_LINK_DLT_TEMPLATE_ID", ASA_INVOICE_LINK_TEMPLATE_ID),
      invoice_return_link_template_id: ENV.fetch("ASA_SMS_INVOICE_RETURN_LINK_DLT_TEMPLATE_ID", ASA_INVOICE_RETURN_LINK_TEMPLATE_ID),
      invoice_otp_template_id: ENV.fetch("ASA_SMS_INVOICE_OTP_DLT_TEMPLATE_ID", ASA_INVOICE_OTP_TEMPLATE_ID),
      vendor_registration_link_template_id: ENV.fetch("ASA_SMS_VENDOR_REGISTRATION_LINK_DLT_TEMPLATE_ID", DEFAULT_VENDOR_REGISTRATION_LINK_TEMPLATE_ID),
      vendor_registration_otp_template_id: ENV.fetch("ASA_SMS_VENDOR_REGISTRATION_OTP_DLT_TEMPLATE_ID", DEFAULT_VENDOR_REGISTRATION_OTP_TEMPLATE_ID)
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
      purchase_order_otp_template_id: ENV.fetch("SMS_PURCHASE_ORDER_OTP_DLT_TEMPLATE_ID", DEFAULT_PURCHASE_ORDER_OTP_TEMPLATE_ID),
      invoice_link_template_id: ENV.fetch("SMS_INVOICE_LINK_DLT_TEMPLATE_ID", DEFAULT_INVOICE_LINK_TEMPLATE_ID),
      invoice_return_link_template_id: ENV.fetch("SMS_INVOICE_RETURN_LINK_DLT_TEMPLATE_ID", DEFAULT_INVOICE_RETURN_LINK_TEMPLATE_ID),
      invoice_otp_template_id: ENV.fetch("SMS_INVOICE_OTP_DLT_TEMPLATE_ID", DEFAULT_INVOICE_OTP_TEMPLATE_ID),
      vendor_registration_link_template_id: ENV.fetch("SMS_VENDOR_REGISTRATION_LINK_DLT_TEMPLATE_ID", DEFAULT_VENDOR_REGISTRATION_LINK_TEMPLATE_ID),
      vendor_registration_otp_template_id: ENV.fetch("SMS_VENDOR_REGISTRATION_OTP_DLT_TEMPLATE_ID", DEFAULT_VENDOR_REGISTRATION_OTP_TEMPLATE_ID)
    }
  end

  def self.otp_template_id_for(config, purpose:)
    case purpose.to_sym
    when :purchase_order
      config[:purchase_order_otp_template_id]
    when :invoice
      config[:invoice_otp_template_id]
    else
      config[:quotation_otp_template_id]
    end
  end

  def self.fallback_template_id_for(config, template_id)
    if template_id.to_s == config[:quotation_link_template_id].to_s
      default_sms_config[:quotation_link_template_id]
    elsif template_id.to_s == config[:purchase_order_link_template_id].to_s
      default_sms_config[:purchase_order_link_template_id]
    elsif template_id.to_s == config[:purchase_order_otp_template_id].to_s
      default_sms_config[:purchase_order_otp_template_id]
    elsif template_id.to_s == config[:invoice_link_template_id].to_s
      default_sms_config[:invoice_link_template_id]
    elsif template_id.to_s == config[:invoice_return_link_template_id].to_s
      default_sms_config[:invoice_return_link_template_id]
    elsif template_id.to_s == config[:invoice_otp_template_id].to_s
      default_sms_config[:invoice_otp_template_id]
    elsif template_id.to_s == config[:vendor_registration_link_template_id].to_s
      default_sms_config[:vendor_registration_link_template_id]
    elsif template_id.to_s == config[:vendor_registration_otp_template_id].to_s
      default_sms_config[:vendor_registration_otp_template_id]
    else
      default_sms_config[:quotation_otp_template_id]
    end
  end

  def self.legacy_fallback_message(message, config)
    return message unless config[:profile] == :asa

    message
      .gsub("Action For Social Advancement(ASA)", "Ploughman Agro Private Limited (PAPL)")
      .gsub("Action For Social Advancement (ASA)", "Ploughman Agro Private Limited (PAPL)")
      .gsub(" using the link below:", " using the link below: ")
      .gsub(".-Ploughman Agro Private Limited (PAPL)", ". - Ploughman Agro Private Limited (PAPL)")
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
      dispatch.try(:quotation_proposal)&.theme&.stakeholder_category&.name,
      dispatch.try(:stakeholder_category)&.name,
      dispatch.try(:vendor_registration)&.stakeholder_category&.name,
    ].compact.map { |value| value.to_s.strip }.find(&:present?).to_s.upcase
  end

  def self.asa_stakeholder?(stakeholder_name)
    normalized_name = stakeholder_name.to_s.upcase
    normalized_name == "ASA" || normalized_name.include?("ACTION FOR SOCIAL ADVANCEMENT")
    end
end
