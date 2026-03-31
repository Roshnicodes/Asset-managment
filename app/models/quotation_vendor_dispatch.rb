class QuotationVendorDispatch < ApplicationRecord
  SESSION_WINDOW = 15.minutes
  OTP_WINDOW = 10.minutes

  belongs_to :quotation_proposal_vendor
  belongs_to :quotation_proposal
  belongs_to :vendor_registration
  belongs_to :user, optional: true
  belongs_to :stakeholder_category, optional: true

  has_many :quotation_vendor_otps, dependent: :destroy

  validates :status, presence: true

  def access_open?
    access_granted? && access_expires_at.present? && access_expires_at.future?
  end

  def latest_active_otp
    quotation_vendor_otps.where(active: true).order(created_at: :desc).first
  end

  def send_new_otp!
    quotation_vendor_otps.where(active: true).update_all(active: false)

    otp = format("%06d", rand(0..999_999))
    otp_record = quotation_vendor_otps.create!(
      quotation_proposal: quotation_proposal,
      vendor_registration: vendor_registration,
      vendor_name: vendor_name,
      mobile_no: mobile_no,
      otp_code: otp,
      sent_at: Time.current,
      expires_at: Time.current + OTP_WINDOW,
      active: true
    )
    QuotationVendorSmsGateway.send_vendor_otp(self, otp_record)
    otp_record
  end

  def verify_otp!(submitted_otp)
    otp_record = latest_active_otp
    return false if otp_record.blank?
    return false if otp_record.expires_at.blank? || otp_record.expires_at.past?
    return false if otp_record.otp_code.to_s != submitted_otp.to_s.strip

    otp_record.update!(verified: true, verified_at: Time.current, active: false)
    update!(
      access_granted: true,
      otp_verified_at: Time.current,
      access_expires_at: Time.current + SESSION_WINDOW,
      status: "otp_verified"
    )
    true
  end
end
