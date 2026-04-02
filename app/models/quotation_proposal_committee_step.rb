class QuotationProposalCommitteeStep < ApplicationRecord
  belongs_to :quotation_proposal
  belongs_to :employee_master

  STATUSES = %w[waiting pending approved returned rejected].freeze

  validates :level, presence: true, inclusion: { in: 1..4 }, uniqueness: { scope: :quotation_proposal_id }
  validates :status, inclusion: { in: STATUSES }

  scope :ordered, -> { order(:level) }

  def approve!(remark: nil)
    update!(status: "approved", remark: remark, actioned_at: Time.current)
  end

  def return!(remark:)
    update!(status: "returned", remark: remark, actioned_at: Time.current)
  end

  def status_label
    return "Returned" if status == "returned"
    return "Rejected" if status == "rejected"
    return "Waiting" if status == "waiting"

    status.capitalize
  end
end
