class OfficeCategory < ApplicationRecord
  OFFICE_LEVELS = ["PMU", "FCO", "TO"].freeze

  belongs_to :stakeholder_category, optional: true
  belongs_to :parent, class_name: "OfficeCategory", optional: true
  has_many :children, class_name: "OfficeCategory", foreign_key: :parent_id, dependent: :restrict_with_error
  # has_many :stakeholder_categories, dependent: :restrict_with_error

  validates :name, :office_level, presence: true
end
