class QuotationProposalVendorPoActivity < ApplicationRecord
  belongs_to :quotation_proposal_vendor
  belongs_to :employee_master, optional: true
  belongs_to :user, optional: true

  validates :action_type, :actor_name, :occurred_at, presence: true

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }
end
