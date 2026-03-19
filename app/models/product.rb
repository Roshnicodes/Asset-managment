class Product < ApplicationRecord
  belongs_to :theme
  has_many :assets
end
