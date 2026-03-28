class DocumentMaster < ApplicationRecord
  belongs_to :stakeholder_category, optional: true
  belongs_to :firm, optional: true

  validates :name, presence: true

  ATTACHMENT_ALIASES = {
    "pan_document" => %w[pan pancard panupload pandocument panfile],
    "aadhar_document" => %w[
      aadhar aadharcard aadharupload aadhardocument
      aadhaar aadhaarcard aadhaarupload aadhaardocument
      adhar adharcard adharupload adhardocument
    ],
    "establishment_certificate" => %w[
      establishmentcertificate establishmentcertificateupload establishmentdocument
      establishcertificate establishcertificateupload registrationcertificate businesscertificate
      establishmentcertificatefile establishmentregistrationcertificate
    ],
    "msme_certificate" => %w[
      msme msmecertificate msmecertificateupload msmecertificatefile
      udyam udyamcertificate udyamregistration udyamregistrationcertificate
    ]
  }.freeze

  def attachment_name
    stored_key = document_key.to_s.strip
    return stored_key if ATTACHMENT_ALIASES.key?(stored_key)

    normalized_name = name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    ATTACHMENT_ALIASES.find { |_attachment_name, aliases| aliases.include?(normalized_name) }&.first
  end

  def supported_for_vendor_upload?
    attachment_name.present?
  end
end
