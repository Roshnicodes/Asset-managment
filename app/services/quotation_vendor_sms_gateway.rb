require "json"
require "net/http"
require "uri"

class QuotationVendorSmsGateway
  API_ENDPOINT = "https://sms.yoursmsbox.com/api/sendhttp.php".freeze
  DEFAULT_AUTHKEY = "37317061706c39353312".freeze
  DEFAULT_SENDER = "PLOAPL".freeze
  DEFAULT_ROUTE = "2".freeze
  DEFAULT_COUNTRY = "0".freeze
  DEFAULT_UNICODE = "1".freeze
  DEFAULT_LINK_TEMPLATE_ID = "1707177502703834106".freeze
  DEFAULT_OTP_TEMPLATE_ID = "1707177503375571501".freeze
  DEFAULT_BASE_URL = "http://127.0.0.1:3000".freeze

  def self.send_vendor_link(dispatch)
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: vendor_link_message(dispatch),
      template_id: DEFAULT_LINK_TEMPLATE_ID
    )
  end

  def self.send_vendor_otp(dispatch, otp_record)
    vendor_name = dispatch.vendor_name.to_s.strip.presence || "Vendor"
    message = "Dear #{vendor_name}, #{otp_record.otp_code} is your one-time password to proceed further with the quotation process. Please do not share this OTP. - PLOUGHMAN AGRO PRIVATE LIMITED"
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: message,
      template_id: ENV.fetch("SMS_OTP_DLT_TEMPLATE_ID", DEFAULT_OTP_TEMPLATE_ID)
    )
  end

  def self.vendor_link_for(token)
    "#{base_url}/vendor_registrations/new"
  end

  def self.vendor_link_message(dispatch)
    vendor_name = dispatch.vendor_name.to_s.strip.presence || "Vendor"
    quotation_reference = quotation_reference_for(dispatch)
    link = vendor_link_for(dispatch.quotation_proposal_vendor.qr_token)

    "Dear #{vendor_name}, PLOUGHMAN AGRO PRIVATE LIMITED requests you to review and accept the quotation proposal #{quotation_reference}. Please submit the quotation using the following link: #{link}."
  end

  def self.send_sms(mobile_no:, message:, template_id:)
    sender = ENV.fetch("SMS_SENDER", DEFAULT_SENDER)
    unicode = unicode_flag_for(message)
    uri = URI(API_ENDPOINT)
    query_params = {
      authkey: ENV.fetch("SMS_AUTHKEY", DEFAULT_AUTHKEY),
      mobiles: normalize_mobile_no(mobile_no),
      message: message,
      sender: sender,
      route: ENV.fetch("SMS_ROUTE", DEFAULT_ROUTE),
      country: ENV.fetch("SMS_COUNTRY", DEFAULT_COUNTRY),
      DLT_TE_ID: template_id,
      unicode: ENV.fetch("SMS_UNICODE", unicode)
    }
    query_params.merge!(pe_id_params)
    uri.query = URI.encode_www_form(query_params)

    response = Net::HTTP.get_response(uri)
    Rails.logger.info("QuotationVendorSmsGateway response=#{response.code} body=#{response.body}")

    return false unless response.is_a?(Net::HTTPSuccess)

    parse_delivery_status(response.body)
  rescue StandardError => error
    Rails.logger.error("QuotationVendorSmsGateway failed: #{error.class} #{error.message}")
    false
  end

  def self.parse_delivery_status(body)
    payload = JSON.parse(body.to_s)
    payload["Status"] == "Success" && payload["Code"] == "000"
  rescue JSON::ParserError => error
    Rails.logger.error("QuotationVendorSmsGateway invalid JSON response: #{error.message} body=#{body}")
    false
  end

  def self.base_url
    ENV.fetch("APP_BASE_URL", DEFAULT_BASE_URL).chomp("/")
  end

  def self.quotation_reference_for(dispatch)
    quotation_proposal = dispatch.try(:quotation_proposal)

    return quotation_proposal.reference_number if quotation_proposal.respond_to?(:reference_number) && quotation_proposal.reference_number.present?
    return quotation_proposal.proposal_number if quotation_proposal.respond_to?(:proposal_number) && quotation_proposal.proposal_number.present?
    return quotation_proposal.id if quotation_proposal.respond_to?(:id) && quotation_proposal.id.present?

    dispatch.quotation_proposal_id
  end

  def self.normalize_mobile_no(mobile_no)
    mobile_no.to_s.gsub(/\s+/, "")
  end

  def self.unicode_flag_for(message)
    return "1" unless message.to_s.ascii_only?

    DEFAULT_UNICODE
  end

  def self.pe_id_params
    pe_id = ENV["SMS_DLT_PE_ID"].to_s.strip
    return {} if pe_id.blank?

    {
      PE_ID: pe_id,
      DLT_PE_ID: pe_id
    }
  end
end
