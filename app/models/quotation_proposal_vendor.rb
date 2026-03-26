class QuotationProposalVendor < ApplicationRecord
  belongs_to :quotation_proposal
  belongs_to :vendor_registration

  validates :qr_token, uniqueness: true, allow_nil: true

  def ensure_qr_token!
    return qr_token if qr_token.present?

    update!(qr_token: generate_unique_qr_token, qr_generated_at: Time.current)
    qr_token
  end

  private

  def generate_unique_qr_token
    loop do
      token = SecureRandom.urlsafe_base64(24)
      break token unless self.class.exists?(qr_token: token)
    end
  end
end
