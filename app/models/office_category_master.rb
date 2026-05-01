class OfficeCategoryMaster < ApplicationRecord
  belongs_to :stakeholder_category
  has_many :office_categories, dependent: :restrict_with_error

  before_validation :normalize_name

  validates :name, presence: true, uniqueness: { scope: :stakeholder_category_id, case_sensitive: false }

  scope :ordered, lambda {
    joins(:stakeholder_category).order("stakeholder_categories.name ASC, office_category_masters.name ASC")
  }

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end
end
