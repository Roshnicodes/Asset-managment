class Firm < ApplicationRecord
  has_many :vendor_registrations, dependent: :nullify

  validates :name, presence: true
end
