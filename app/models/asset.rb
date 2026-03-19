class Asset < ApplicationRecord
  belongs_to :product
  has_many :allocations
end
