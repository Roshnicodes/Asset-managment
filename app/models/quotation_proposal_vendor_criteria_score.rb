class QuotationProposalVendorCriteriaScore < ApplicationRecord
  belongs_to :quotation_proposal_vendor
  belongs_to :quotation_proposal_criteria_selection
  belongs_to :employee_master

  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10, only_integer: true }
  validates :employee_master_id,
            uniqueness: {
              scope: [:quotation_proposal_vendor_id, :quotation_proposal_criteria_selection_id]
            }
  validate :criterion_belongs_to_same_quotation_proposal

  after_save_commit :sync_parent_vendor_score
  after_destroy_commit :sync_parent_vendor_score_after_destroy

  private

  def criterion_belongs_to_same_quotation_proposal
    return if quotation_proposal_vendor.blank? || quotation_proposal_criteria_selection.blank?
    return if quotation_proposal_vendor.quotation_proposal_id == quotation_proposal_criteria_selection.quotation_proposal_id

    errors.add(:quotation_proposal_criteria_selection, "must belong to the same quotation proposal")
  end

  def sync_parent_vendor_score
    quotation_proposal_vendor&.sync_committee_score_for!(employee_master)
  end

  def sync_parent_vendor_score_after_destroy
    vendor = QuotationProposalVendor.find_by(id: quotation_proposal_vendor_id)
    employee = EmployeeMaster.find_by(id: employee_master_id)
    vendor&.sync_committee_score_for!(employee) if employee.present?
  end
end
