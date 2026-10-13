require "uri"

# Sends a copy of every in-app notification by email through krai (the server
# has no SMTP), the same way payment advice mails go, through one Apurti page:
#
#   GET https://krai.asaindia.org/apurti_nnotify.aspx?to_email=...&to_name=...&subject=...&message=...&link=...
#
# NOTIFICATION_MAIL_RELAY_URL is krai's address (https://krai.asaindia.org/) or
# a full page address (…/x.aspx). One kind can get its own page with
# NOTIFICATION_MAIL_PAGE_<KIND>, e.g. NOTIFICATION_MAIL_PAGE_INVOICE_ACCEPTED=x.aspx.
#
# Off until NOTIFICATION_MAIL_RELAY_URL is set, so nothing changes before krai
# provides the pages. Redirects and the answer are handled like payment advice.
class NotificationMailRelay
  class DeliveryError < StandardError; end

  FIELDS = %w[to_email to_name subject message link].freeze

  # Kinds set in NotificationDispatcher. All go to krai's one Apurti page unless
  # a kind is given its own page with NOTIFICATION_MAIL_PAGE_<KIND>.
  KINDS = %w[
    approval_pending
    approval_reminder
    approval_approved
    approval_rejected
    approval_returned
    approval_returned_to_level
    thematic_head_decision_request
    thematic_head_decided
    committee_approval_pending
    committee_approved
    committee_returned
    vendor_response_received
    purchase_order_sent
    purchase_order_reply_updated
    purchase_order_vendor_response
    invoice_requested
    invoice_uploaded
    invoice_returned
    invoice_accepted
    payment_recorded
  ].freeze
  DEFAULT_PAGE = "apurti_nnotify.aspx".freeze

  def self.url
    ENV["NOTIFICATION_MAIL_RELAY_URL"].to_s.strip
  end

  def self.enabled?
    url.present?
  end

  # Full krai address for one kind of notification.
  def self.page_url(kind)
    base = URI.parse(url)
    own_page = kind.present? ? ENV["NOTIFICATION_MAIL_PAGE_#{kind.to_s.upcase}"].to_s.strip.presence : nil
    return base.to_s if own_page.nil? && base.path.to_s.end_with?(".aspx")

    page = own_page || DEFAULT_PAGE
    URI.join(base.to_s.end_with?("/") || base.path.to_s.end_with?(".aspx") ? base.to_s : "#{base}/", page).to_s
  end

  def self.params_for(notification)
    user = notification.user
    {
      "to_email" => user&.email.to_s.strip,
      "to_name" => user&.employee_master&.name.presence || user&.email.to_s,
      "subject" => notification.title.to_s,
      "message" => notification.message.to_s,
      "link" => link_for(notification)
    }
  end

  # The record the notification is about, opened in Apurti.
  def self.link_for(notification)
    helpers = Rails.application.routes.url_helpers
    options = link_url_options
    record = notification.notifiable
    record = record.approvable if record.is_a?(ApprovalRequest)

    case record
    when QuotationProposal then helpers.quotation_proposal_url(record, **options)
    when VendorRegistration then helpers.vendor_registration_url(record, **options)
    else helpers.notifications_url(**options)
    end
  rescue StandardError
    ""
  end

  def self.link_url_options
    base = ENV["NOTIFICATION_MAIL_APP_URL"].presence
    return {} if base.blank?

    uri = URI.parse(base)
    { host: uri.host, protocol: uri.scheme, port: uri.port == uri.default_port ? nil : uri.port }.compact
  end

  def self.request_uri(notification)
    uri = URI.parse(page_url(notification.mail_kind))
    uri.query = URI.encode_www_form(params_for(notification))
    uri
  end

  def self.deliver!(notification)
    params = params_for(notification)
    return false unless params["to_email"].include?("@")

    response, final_uri = PaymentAdviceMailRelay.fetch(request_uri(notification))
    where = "[#{final_uri.scheme}://#{final_uri.host}#{final_uri.path}]"
    raise DeliveryError, "Mail service asked for a login #{where}" if PaymentAdviceMailRelay.login_page?(final_uri)
    raise DeliveryError, "#{PaymentAdviceMailRelay.failure_message(response)} #{where}" unless PaymentAdviceMailRelay.success?(response)

    Rails.logger.info("NotificationMailRelay sent notification=#{notification.id} kind=#{notification.mail_kind} to=#{params['to_email']} status=#{response.code}")
    true
  end
end
