class VendorRegistration < ApplicationRecord
  GST_NO_FORMAT = /\A\d{2}[A-Z]{5}\d{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}\z/.freeze
  PAN_NO_FORMAT = /\A[A-Z]{5}\d{4}[A-Z]\z/.freeze
  MOBILE_NO_FORMAT = /\A[6-9]\d{9}\z/.freeze
  PIN_NO_FORMAT = /\A[1-9]\d{5}\z/.freeze

  belongs_to :user, optional: true
  belongs_to :stakeholder_category, optional: true
  belongs_to :registration_type, optional: true
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
  has_many :quotation_proposal_vendors, dependent: :restrict_with_error
  has_many :quotation_proposals, through: :quotation_proposal_vendors
  has_one :approval_request, as: :approvable, dependent: :destroy
  has_one_attached :msme_certificate
  has_one_attached :pan_document
  has_one_attached :aadhar_document
  has_one_attached :establishment_certificate

  attr_accessor :incoming_document_files
  accepts_nested_attributes_for :vendor_bank_masters, allow_destroy: true, reject_if: :all_blank

  validates :stakeholder_category, :firm_name, :vendor_name, :firm_type, :pan_no, :email, :mobile_no, :address,
            :state, :district, :block, :pin_no, :contact_person_name, :contact_person_designation,
            :company_status, :firm_profile, :business_description, presence: true
  validate :theme_selection_required
  validate :product_selection_required
  validate :product_variety_selection_required
  validate :bank_details_required
  validate :aadhar_document_required_for_proprietor
  validates :gst_no, format: { with: GST_NO_FORMAT, message: "must be a valid 15-character GST number" }, allow_blank: true
  validates :pan_no, format: { with: PAN_NO_FORMAT, message: "must be a valid 10-character PAN number" }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validates :mobile_no, format: { with: MOBILE_NO_FORMAT, message: "must be a valid 10-digit Indian mobile number starting with 6, 7, 8, or 9" }, allow_blank: true
  validates :pin_no, format: { with: PIN_NO_FORMAT, message: "must be a valid 6-digit PIN code" }, allow_blank: true
  validate :gst_no_required_for_company
  validate :msme_details_required_if_applicable
  validate :required_documents_must_be_uploaded
  before_validation :normalize_registration_fields
  before_validation :clear_msme_details_unless_applicable
  after_commit :persist_incoming_document_files, on: %i[create update]

  def display_name
    vendor_name.presence || firm_name.presence || "Vendor Registration ##{id}"
  end

  def approval_locked?
    approval_request&.status == "approved"
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

  def company_firm_type?
    firm_type.to_s.strip.casecmp("company").zero?
  end

  private

  def normalize_registration_fields
    self.gst_no = gst_no.to_s.strip.upcase.presence
    self.pan_no = pan_no.to_s.strip.upcase.presence
    self.email = email.to_s.strip.downcase.presence
    self.address = address.to_s.strip.presence
    self.mobile_no = mobile_no.to_s.gsub(/\D/, "").presence
    self.pin_no = pin_no.to_s.gsub(/\D/, "").presence
  end

  def clear_msme_details_unless_applicable
    return if msme?

    self.msme_number = nil
    msme_certificate.detach if msme_certificate.attached?
  end

  def gst_no_required_for_company
    return unless company_firm_type?
    return if gst_no.present?

    errors.add(:gst_no, "can't be blank")
  end

  def theme_selection_required
    errors.add(:theme_ids, "must select at least one theme") if theme_ids.reject(&:blank?).blank?
  end

  def product_selection_required
    errors.add(:product_ids, "must select at least one product") if product_ids.reject(&:blank?).blank?
  end

  def product_variety_selection_required
    errors.add(:product_variety_ids, "must select at least one product variety") if product_variety_ids.reject(&:blank?).blank?
  end

  def bank_details_required
    active_bank_masters = vendor_bank_masters.reject(&:marked_for_destruction?)
    if active_bank_masters.blank?
      errors.add(:vendor_bank_masters, "must include bank details")
      return
    end

    active_bank_masters.each do |bank|
      bank.errors.add(:bank_name, "can't be blank") if bank.bank_name.blank?
      bank.errors.add(:account_type, "can't be blank") if bank.account_type.blank?
      bank.errors.add(:account_number, "can't be blank") if bank.account_number.blank?
      bank.errors.add(:ifsc_code, "can't be blank") if bank.ifsc_code.blank?
      bank.errors.add(:bank_address, "can't be blank") if bank.bank_address.blank?

      cheque_attached = bank.cancelled_cheque.attached? || bank.attachment_changes["cancelled_cheque"].present?
      bank.errors.add(:cancelled_cheque, "must be uploaded") unless cheque_attached
    end

    errors.add(:vendor_bank_masters, "bank details are incomplete") if active_bank_masters.any? { |bank| bank.errors.any? }
  end

  def aadhar_document_required_for_proprietor
    return unless firm_type.to_s.strip.casecmp("proprietor").zero?
    return if aadhar_document.attached?

    errors.add(:aadhar_document, "must be uploaded")
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
    uploads = normalized_incoming_document_files
    uploads[document_master.id.to_s] || uploads[document_master.id]
  end

  def persist_incoming_document_files
    return if incoming_document_files.blank?

    normalized_incoming_document_files.each do |document_master_id, uploaded_file|
      next if uploaded_file.blank?

      document = vendor_registration_documents.find_or_initialize_by(document_master_id: document_master_id)
      document.file.attach(uploaded_file)
      document.save! if document.new_record? || document.changed?
    end

    self.incoming_document_files = nil
  end

  def normalized_incoming_document_files
    case incoming_document_files
    when ActionController::Parameters
      incoming_document_files.permit!.to_h
    when Hash
      incoming_document_files
    else
      incoming_document_files.to_h
    end
  end
end
