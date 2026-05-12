class QuotationProposalCriteriaSelection < ApplicationRecord
  belongs_to :quotation_proposal
  belongs_to :vendor_selection_criterion, optional: true

  has_many :committee_criteria_scores,
           class_name: "QuotationProposalVendorCriteriaScore",
           dependent: :destroy,
           inverse_of: :quotation_proposal_criteria_selection

  validates :criterion_label, presence: true
  validates :vendor_selection_criterion_id, uniqueness: { scope: :quotation_proposal_id }, allow_nil: true

  scope :ordered, -> { order(:created_at, :id) }

  def display_label
    criterion_label.presence || vendor_selection_criterion&.criteria.to_s
  end
end
