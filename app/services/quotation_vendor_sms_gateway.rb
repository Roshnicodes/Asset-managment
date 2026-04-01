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
  DEFAULT_LINK_TEMPLATE_ID = "1707175808823040868".freeze
  DEFAULT_OTP_TEMPLATE_ID = "1707177503375571501".freeze
  DEFAULT_BASE_URL = "http://127.0.0.1:3000".freeze

  def self.send_vendor_link(dispatch)
    link = vendor_link_for(dispatch.quotation_proposal_vendor.qr_token)
    message = "ASA Vendor #{dispatch.vendor_name} quotation ##{dispatch.quotation_proposal_id} link: #{link} Mobile: #{dispatch.mobile_no}"
    send_sms(
      mobile_no: dispatch.mobile_no,
      message: message,
      template_id: ENV.fetch("SMS_LINK_DLT_TEMPLATE_ID", DEFAULT_LINK_TEMPLATE_ID)
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
    "#{base_url}/quotation-vendor-qr/#{token}"
  end

  def self.send_sms(mobile_no:, message:, template_id:)
    sender = ENV.fetch("SMS_SENDER", DEFAULT_SENDER)
    uri = URI(API_ENDPOINT)
    uri.query = URI.encode_www_form(
      authkey: ENV.fetch("SMS_AUTHKEY", DEFAULT_AUTHKEY),
      mobiles: mobile_no,
      message: message,
      sender: sender,
      route: ENV.fetch("SMS_ROUTE", DEFAULT_ROUTE),
      country: ENV.fetch("SMS_COUNTRY", DEFAULT_COUNTRY),
      DLT_TE_ID: template_id,
      unicode: ENV.fetch("SMS_UNICODE", DEFAULT_UNICODE)
    )

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
end
