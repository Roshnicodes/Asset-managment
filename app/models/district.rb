class District < ApplicationRecord
  belongs_to :state
  has_many :pmus, dependent: :restrict_with_error
  has_many :blocks, dependent: :restrict_with_error
  has_many :vendor_registrations, dependent: :restrict_with_error

  validates :name, presence: true
end
