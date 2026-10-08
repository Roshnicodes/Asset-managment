require "json"
require "net/http"
require "openssl"
require "uri"

# Sends payment advice mails through the ASA mail service (krai) because the
# server has no SMTP. The Apurti server calls krai's nemail.aspx page with the
# advice details as query parameters; krai builds the mail and sends it.
#
#   GET https://krai.asaindia.org/nemail.aspx?company_name=...&advice_no=...&...&remarks=
#
# If PAYMENT_ADVICE_MAIL_RELAY_SECRET is set, the link also carries
# expires_at=<unix> and signature=HMAC-SHA256(secret, values of SIGNED_FIELDS
# in that order, then expires_at, joined by "|") so krai can verify it.
# A 2xx answer is a success unless its JSON says otherwise
# ("success": false, or "status": "error"/"failed").
class PaymentAdviceMailRelay
  class DeliveryError < StandardError; end

  DEFAULT_URL = "https://krai.asaindia.org/nemail.aspx".freeze
  MAIL_PAGE = "/nemail.aspx".freeze
  TIMEOUT_SECONDS = 15
  LINK_VALID_FOR = 10.minutes
  SIGNED_FIELDS = %w[
    company_name advice_no payee_name payee_email invoice_no invoice_date
    gross_amount tds_amount other_deduction net_amount payment_mode
    reference_no bank_name payment_date remarks
  ].freeze

  # Used when the server has no real SMTP; tests and local file delivery keep
  # the normal mailer, and an explicit relay URL always switches it on.
  def self.enabled?
    return true if ENV["PAYMENT_ADVICE_MAIL_RELAY_URL"].present?
    return false if Rails.env.test? || PaymentAdviceMailer.payment_advice_local_file_delivery?

    !PaymentAdviceMailer.payment_advice_real_smtp_configured?
  end

  # A configured bare host (e.g. the older "https://krai.asaindia.org/") still
  # points at the mail page.
  def self.url
    configured = ENV["PAYMENT_ADVICE_MAIL_RELAY_URL"].presence || DEFAULT_URL
    uri = URI.parse(configured)
    uri.path = MAIL_PAGE if uri.path.blank? || uri.path == "/"
    uri.to_s
  end

  def self.secret
    ENV["PAYMENT_ADVICE_MAIL_RELAY_SECRET"].to_s
  end

  def self.deliver!(payment_advice, now: Time.current)
    response, final_uri = fetch(signed_url(payment_advice, now: now))
    # The address (without the advice details) helps to see where it went.
    where = "[#{final_uri.scheme}://#{final_uri.host}#{final_uri.path}]"
    raise DeliveryError, "Mail service asked for a login #{where}" if login_page?(final_uri)
    raise DeliveryError, "#{failure_message(response)} #{where}" unless success?(response)

    Rails.logger.info("PaymentAdviceMailRelay sent advice=#{payment_advice.advice_no} to=#{payment_advice.payee_email} status=#{response.code} #{where}")
    true
  rescue DeliveryError => error
    Rails.logger.error("PaymentAdviceMailRelay failed advice=#{payment_advice.advice_no}: #{error.message}")
    raise
  rescue StandardError => error
    Rails.logger.error("PaymentAdviceMailRelay failed advice=#{payment_advice.advice_no}: #{error.class} #{error.message}")
    raise DeliveryError, "Mail service could not be reached (#{error.message})."
  end

  def self.params_for(payment_advice)
    {
      "company_name" => payment_advice.company_name,
      "advice_no" => payment_advice.advice_no,
      "payee_name" => payment_advice.payee_name,
      "payee_email" => payment_advice.payee_email,
      "invoice_no" => payment_advice.invoice_no,
      "invoice_date" => payment_advice.invoice_date&.iso8601,
      "gross_amount" => payment_advice.gross_amount.to_s,
      "tds_amount" => payment_advice.tds_amount.to_s,
      "other_deduction" => payment_advice.other_deduction.to_s,
      "net_amount" => payment_advice.net_amount.to_s,
      "payment_mode" => payment_advice.payment_mode,
      "reference_no" => payment_advice.reference_no,
      "bank_name" => payment_advice.bank_name,
      "payment_date" => payment_advice.payment_date&.iso8601,
      "remarks" => payment_advice.remarks
    }.transform_values { |value| value.to_s }
  end

  def self.signature_for(params, expires_at)
    string_to_sign = (SIGNED_FIELDS.map { |field| params[field].to_s } + [expires_at.to_s]).join("|")
    OpenSSL::HMAC.hexdigest("SHA256", secret, string_to_sign)
  end

  # The link carries expires_at and signature only when a shared secret is set.
  def self.signed_url(payment_advice, now: Time.current)
    query = params_for(payment_advice)
    if secret.present?
      expires_at = (now + LINK_VALID_FOR).to_i
      query = query.merge("expires_at" => expires_at.to_s, "signature" => signature_for(query, expires_at))
    end

    uri = URI.parse(url)
    uri.query = URI.encode_www_form(query)
    uri
  end

  MAX_REDIRECTS = 3

  # krai's page may answer with a redirect (302 "Object moved") to a result
  # page; follow it and judge the page it ends on.
  def self.fetch(uri)
    response = get(uri)
    MAX_REDIRECTS.times do
      break unless response.is_a?(Net::HTTPRedirection) && response["location"].present?

      next_uri = URI.join(uri.to_s, response["location"])
      Rails.logger.info("PaymentAdviceMailRelay redirect #{response.code} -> #{next_uri.scheme}://#{next_uri.host}#{next_uri.path}")
      uri = next_uri
      response = get(uri)
    end
    [response, uri]
  end

  def self.login_page?(uri)
    uri.path.to_s.downcase.match?(/login|signin|sign_in/)
  end

  def self.get(uri)
    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/json"

    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                    open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      http.request(request)
    end
  end

  def self.success?(response)
    return false unless response.is_a?(Net::HTTPSuccess)

    body = parsed_body(response)
    return true unless body.is_a?(Hash)
    return false if body.key?("success") && !ActiveModel::Type::Boolean.new.cast(body["success"])

    !body["status"].to_s.downcase.in?(%w[error failed failure])
  end

  def self.failure_message(response)
    body = parsed_body(response)
    detail = body["message"] || body["error"] if body.is_a?(Hash)
    detail ||= response.body.to_s.gsub(/<[^>]+>/, " ").squish.first(160)
    "Mail service returned #{response.code}: #{detail.presence || response.message}"
  end

  def self.parsed_body(response)
    JSON.parse(response.body.to_s)
  rescue JSON::ParserError
    nil
  end
end
