require "net/http"
require "uri"

class QuotationVendorSmsGateway
  API_ENDPOINT = "https://sms.yoursmsbox.com/api/sendhttp.php".freeze
  DEFAULT_AUTHKEY = "3230666f72736131353261".freeze
  DEFAULT_SENDER = "ACTFSA".freeze
  DEFAULT_ROUTE = "2".freeze
  DEFAULT_COUNTRY = "0".freeze
  DEFAULT_TEMPLATE_ID = "1707175808823040868".freeze
  DEFAULT_BASE_URL = "http://127.0.0.1:3000".freeze

  def self.send_vendor_link(dispatch)
    link = vendor_link_for(dispatch.quotation_proposal_vendor.qr_token)
    message = "ASA Vendor #{dispatch.vendor_name} quotation ##{dispatch.quotation_proposal_id} link: #{link} Mobile: #{dispatch.mobile_no}"
    send_sms(mobile_no: dispatch.mobile_no, message: message)
  end

  def self.send_vendor_otp(dispatch, otp_record)
    message = "ASA Vendor #{dispatch.vendor_name} OTP for quotation ##{dispatch.quotation_proposal_id} is #{otp_record.otp_code}. It is valid for 10 minutes."
    send_sms(mobile_no: dispatch.mobile_no, message: message)
  end

  def self.vendor_link_for(token)
    "#{base_url}/quotation-vendor-qr/#{token}"
  end

  def self.send_sms(mobile_no:, message:)
    uri = URI(API_ENDPOINT)
    uri.query = URI.encode_www_form(
      authkey: ENV.fetch("SMS_AUTHKEY", DEFAULT_AUTHKEY),
      mobiles: mobile_no,
      message: message,
      sender: ENV.fetch("SMS_SENDER", DEFAULT_SENDER),
      route: ENV.fetch("SMS_ROUTE", DEFAULT_ROUTE),
      country: ENV.fetch("SMS_COUNTRY", DEFAULT_COUNTRY),
      DLT_TE_ID: ENV.fetch("SMS_DLT_TEMPLATE_ID", DEFAULT_TEMPLATE_ID)
    )

    response = Net::HTTP.get_response(uri)
    Rails.logger.info("QuotationVendorSmsGateway response=#{response.code} body=#{response.body}")
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError => error
    Rails.logger.error("QuotationVendorSmsGateway failed: #{error.class} #{error.message}")
    false
  end

  def self.base_url
    ENV.fetch("APP_BASE_URL", DEFAULT_BASE_URL).chomp("/")
  end
end
