class Firm < ApplicationRecord
  belongs_to :stakeholder_category, optional: true
  has_many :vendor_registrations, dependent: :nullify

  validates :name, presence: true
end
