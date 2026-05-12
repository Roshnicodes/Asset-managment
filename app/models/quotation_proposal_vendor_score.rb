class QuotationProposalVendorScore < ApplicationRecord
  belongs_to :quotation_proposal_vendor
  belongs_to :employee_master

  validates :employee_master_id, uniqueness: { scope: :quotation_proposal_vendor_id }
  validates :score, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
  validates :remark, length: { maximum: 1000 }, allow_blank: true

  after_commit :sync_parent_vendor_score

  private

  def sync_parent_vendor_score
    return if quotation_proposal_vendor.destroyed?

    quotation_proposal_vendor.sync_cached_committee_score!
  end
end
