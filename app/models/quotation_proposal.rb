class QuotationProposal < ApplicationRecord
  belongs_to :theme
  belongs_to :user, optional: true

  has_many :quotation_proposal_vendors, dependent: :destroy
  has_many :vendor_registrations, through: :quotation_proposal_vendors
  has_many :quotation_proposal_items, dependent: :destroy, inverse_of: :quotation_proposal
  has_one :approval_request, as: :approvable, dependent: :destroy

  accepts_nested_attributes_for :quotation_proposal_items, allow_destroy: true, reject_if: :all_blank

  validates :subject, :proposal_end_date, :theme, presence: true
  validate :must_have_at_least_one_vendor
  validate :must_have_at_least_one_item

  def display_name
    subject
  end

  def stakeholder_category_id
    theme&.stakeholder_category_id
  end

  def generate_vendor_qr_tokens!
    quotation_proposal_vendors.find_each(&:ensure_qr_token!)
  end

  private

  def must_have_at_least_one_vendor
    errors.add(:base, "Select at least one vendor.") if vendor_registrations.blank?
  end

  def must_have_at_least_one_item
    kept_items = quotation_proposal_items.reject(&:marked_for_destruction?)
    errors.add(:base, "Add at least one item.") if kept_items.empty?
  end
end
