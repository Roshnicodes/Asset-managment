class District < ApplicationRecord
  belongs_to :state
  has_many :pmus, dependent: :restrict_with_error
end
