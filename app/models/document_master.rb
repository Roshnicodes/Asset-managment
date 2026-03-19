class DocumentMaster < ApplicationRecord
  validates :name, presence: true
end
