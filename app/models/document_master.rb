class DocumentMaster < ApplicationRecord
  belongs_to :stakeholder_category, optional: true

  validates :name, presence: true
end
