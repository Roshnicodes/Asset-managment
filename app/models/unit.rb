class Unit < ApplicationRecord
  belongs_to :stakeholder_category, optional: true
  has_many :quotation_proposal_items, dependent: :restrict_with_error

  validates :name, presence: true
end
