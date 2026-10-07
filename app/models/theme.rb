class Theme < ApplicationRecord
  belongs_to :stakeholder_category, optional: true
  has_many :products, dependent: :restrict_with_error
  has_many :vendor_selection_criteria, dependent: :restrict_with_error
  has_many :vendor_registration_themes, dependent: :destroy
  has_many :vendor_registrations, through: :vendor_registration_themes

  validates :name, presence: true

  # WRD requests pick an Activity (one of the theme's products) and the maker
  # types the item names under it.
  def wrd?
    name.to_s.strip.match?(/\AWRD\b/i)
  end
end
