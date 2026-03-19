class Block < ApplicationRecord
  belongs_to :district
  has_many :vendor_registrations, dependent: :restrict_with_error

  validates :name, presence: true
end
