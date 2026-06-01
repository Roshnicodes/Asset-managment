class VendorRegistrationInvitation < ApplicationRecord
  class SmsDeliveryError < StandardError; end

  OTP_WINDOW = 10.minutes
  SESSION_WINDOW = 30.minutes
  SMS_TOKEN_LENGTH = 12

  belongs_to :user, optional: true
  belongs_to :stakeholder_category, optional: true
  belongs_to :vendor_registration, optional: true

  validates :mobile_no, presence: true, format: { with: VendorRegistration::MOBILE_NO_FORMAT, message: "must be a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9" }
  validates :token, presence: true, uniqueness: true
  validates :status, presence: true

  before_validation :normalize_mobile_no
  before_validation :ensure_token

  def registration_link
    QuotationVendorSmsGateway.vendor_registration_link_for(token, config: QuotationVendorSmsGateway.sms_config_for(self))
  end

  def access_open?
    otp_verified_at.present? && access_expires_at.present? && access_expires_at.future?
  end

  def mark_sent!
    update!(sent_at: Time.current, status: "sent")
  end

  def mark_opened!
    update!(opened_at: Time.current, status: "opened") if opened_at.blank? || status == "sent"
  end

  def send_registration_link!
    ensure_sms_friendly_token!
    delivered = QuotationVendorSmsGateway.send_vendor_registration_link(self)
    unless delivered
      message = QuotationVendorSmsGateway.last_error_message.presence ||
        "Vendor registration link SMS could not be delivered. Please verify the SMS sender/header and template configuration."
      raise SmsDeliveryError, message
    end

    mark_sent!
  end

  def send_new_otp!
    self.otp_code = format("%06d", rand(0..999_999))
    self.otp_sent_at = Time.current
    self.otp_expires_at = Time.current + OTP_WINDOW
    self.otp_verified_at = nil
    self.access_expires_at = nil
    self.status = "otp_sent"
    save!

    delivered = QuotationVendorSmsGateway.send_vendor_registration_otp(self)
    unless delivered
      update!(otp_code: nil, otp_expires_at: nil)
      message = QuotationVendorSmsGateway.last_error_message.presence ||
        "OTP SMS could not be delivered. Please verify the SMS sender/header and template configuration."
      raise SmsDeliveryError, message
    end

    true
  end

  def verify_otp!(submitted_otp)
    return false if otp_code.blank?
    return false if otp_expires_at.blank? || otp_expires_at.past?
    return false if otp_code.to_s != submitted_otp.to_s.strip

    update!(
      otp_verified_at: Time.current,
      access_expires_at: Time.current + SESSION_WINDOW,
      status: "otp_verified"
    )
    true
  end

  private

  def normalize_mobile_no
    digits = mobile_no.to_s.gsub(/\D+/, "")
    digits = digits.delete_prefix("0") if digits.length == 11 && digits.start_with?("0")
    digits = digits.delete_prefix("91") if digits.length == 12 && digits.start_with?("91")
    self.mobile_no = digits.presence
  end

  def ensure_token
    self.token ||= self.class.generate_unique_token
  end

  def ensure_sms_friendly_token!
    return token if sms_friendly_token?

    update!(token: self.class.generate_unique_token)
    token
  end

  def sms_friendly_token?
    token.present? && token.match?(/\A[a-zA-Z0-9]{1,#{SMS_TOKEN_LENGTH}}\z/)
  end

  def self.generate_unique_token
    loop do
      token = SecureRandom.alphanumeric(SMS_TOKEN_LENGTH)
      break token unless exists?(token: token)
    end
  end
end
