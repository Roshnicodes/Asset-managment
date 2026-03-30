class VendorRegistration < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :stakeholder_category, optional: true
  belongs_to :registration_type
  belongs_to :firm, optional: true
  belongs_to :state
  belongs_to :district
  belongs_to :block
  has_many :vendor_registration_themes, dependent: :destroy
  has_many :themes, through: :vendor_registration_themes
  has_many :vendor_registration_products, dependent: :destroy
  has_many :products, through: :vendor_registration_products
  has_many :vendor_registration_product_varieties, dependent: :destroy
  has_many :product_varieties, through: :vendor_registration_product_varieties
  has_many :vendor_bank_masters, dependent: :destroy
  has_many :vendor_registration_documents, dependent: :destroy
  has_one :approval_request, as: :approvable, dependent: :destroy
  has_one_attached :msme_certificate
  has_one_attached :pan_document
  has_one_attached :aadhar_document
  has_one_attached :establishment_certificate

  attr_accessor :incoming_document_files
  accepts_nested_attributes_for :vendor_bank_masters, allow_destroy: true, reject_if: :all_blank

  validates :vendor_name, :email, :mobile_no, :company_status, presence: true
  validate :msme_details_required_if_applicable
  validate :required_documents_must_be_uploaded
  before_validation :clear_msme_details_unless_applicable
  after_commit :persist_incoming_document_files, on: %i[create update]

  def display_name
    vendor_name.presence || company_name.presence || "Vendor Registration ##{id}"
  end

  def attachment_for(document_key)
    case document_key.to_s
    when "msme_certificate" then msme_certificate
    when "pan_document" then pan_document
    when "aadhar_document" then aadhar_document
    when "establishment_certificate" then establishment_certificate
    end
  end

  def document_record_for(document_master)
    vendor_registration_documents.detect { |document| document.document_master_id == document_master.id } ||
      vendor_registration_documents.find_by(document_master_id: document_master.id) ||
      vendor_registration_documents.build(document_master: document_master)
  end

  def document_attachment_for(document_master)
    dynamic_attachment = document_record_for(document_master).file
    return dynamic_attachment if dynamic_attachment.attached?

    attachment_name = document_master.attachment_name
    attachment_for(attachment_name)
  end

  def document_file_attached?(document_master)
    incoming_file_for(document_master).present? || document_attachment_for(document_master)&.attached?
  end

  def applicable_document_masters
    scope = DocumentMaster.includes(:firm).order(:name)
    scope = scope.where(stakeholder_category_id: [stakeholder_category_id, nil]) if stakeholder_category_id.present?

    scope.select do |document_master|
      next false if document_master.firm_id.present? && firm_id.present? && document_master.firm_id != firm_id
      next false if document_master.msme_only? && !msme?

      true
    end
  end

  def document_masters_for_form(document_masters)
    document_masters.select do |document_master|
      next false if stakeholder_category_id.present? && document_master.stakeholder_category_id.present? && document_master.stakeholder_category_id != stakeholder_category_id
      next false if firm_id.present? && document_master.firm_id.present? && document_master.firm_id != firm_id

      true
    end
  end

  private

  def clear_msme_details_unless_applicable
    return if msme?

    self.msme_number = nil
    msme_certificate.detach if msme_certificate.attached?
  end

  def msme_details_required_if_applicable
    return unless msme?

    errors.add(:msme_number, "can't be blank") if msme_number.blank?

    msme_document_master = applicable_document_masters.find { |document_master| document_master.attachment_name == "msme_certificate" }

    if msme_document_master.present?
      errors.add(:msme_certificate, "must be uploaded") unless document_file_attached?(msme_document_master)
    else
      errors.add(:msme_certificate, "must be uploaded") unless msme_certificate.attached?
    end
  end

  def required_documents_must_be_uploaded
    applicable_document_masters.each do |document_master|
      next unless document_master.mandatory?
      next if document_file_attached?(document_master)

      errors.add(:base, "#{document_master.name} must be uploaded")
    end
  end

  def incoming_file_for(document_master)
    incoming_document_files.to_h[document_master.id.to_s] || incoming_document_files.to_h[document_master.id]
  end

  def persist_incoming_document_files
    return if incoming_document_files.blank?

    incoming_document_files.to_h.each do |document_master_id, uploaded_file|
      next if uploaded_file.blank?

      document = vendor_registration_documents.find_or_initialize_by(document_master_id: document_master_id)
      document.file.attach(uploaded_file)
      document.save! if document.new_record? || document.changed?
    end

    self.incoming_document_files = nil
  end
end
