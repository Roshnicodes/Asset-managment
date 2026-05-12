class OfficeCategory < ApplicationRecord
  attribute :state_id, :integer
  attribute :district_id, :integer
  attribute :block_id, :integer

  belongs_to :stakeholder_category
  belongs_to :office_category_master
  belongs_to :state, optional: true
  belongs_to :district, optional: true
  belongs_to :block, optional: true
  belongs_to :parent, class_name: "OfficeCategory", optional: true
  has_many :children, class_name: "OfficeCategory", foreign_key: :parent_id, dependent: :restrict_with_error

  before_validation :sync_location_hierarchy
  before_validation :build_name_from_location
  before_validation :sync_legacy_office_level

  validates :stakeholder_category, :office_category_master, presence: true
  validate :location_or_parent_present
  validate :parent_belongs_to_same_stakeholder
  validate :parent_cannot_be_self
  validate :district_belongs_to_state
  validate :block_belongs_to_district
  validate :category_master_matches_stakeholder

  delegate :name, to: :office_category_master, prefix: true, allow_nil: true

  scope :ordered, lambda {
    left_outer_joins(:stakeholder_category, :office_category_master)
      .includes(:stakeholder_category, :office_category_master, :state, :district, :block, parent: [:state, :district, :block, :office_category_master])
      .order("stakeholder_categories.name ASC, office_category_masters.name ASC, office_categories.name ASC")
  }

  def location_summary
    [block&.name, district&.name, state&.name].compact.uniq.join(" / ")
  end

  def display_name
    name.presence || [office_category_master_name.presence || office_level.presence, location_summary.presence || state&.name].compact.join(" - ")
  end

  def asset_code_segment
    category_label = office_category_master_name.to_s.strip.presence || office_level.to_s.strip.presence
    location_label = asset_location_name

    [category_label, location_label].compact.join("-")
  end

  private

  def asset_location_name
    block&.name.presence ||
      district&.name.presence ||
      state&.name.presence ||
      stripped_name_without_category.presence ||
      name.to_s.strip.presence ||
      "Office"
  end

  def stripped_name_without_category
    raw_name = name.to_s.strip
    category_label = office_category_master_name.to_s.strip
    return raw_name if raw_name.blank? || category_label.blank?

    raw_name.sub(/\A#{Regexp.escape(category_label)}\s*[-\/]?\s*/i, "").strip
  end

  def sync_location_hierarchy
    if block.present?
      self.district = block.district
      self.state = block.district&.state
    elsif district.present?
      self.state = district.state
    end
  end

  def build_name_from_location
    return if name.present?

    generated_location = location_summary.presence || state&.name.presence || parent&.display_name.presence || "Office"
    category_label = office_category_master&.name.to_s.strip.presence || office_level.to_s.strip.presence || "Category"
    self.name = [category_label, generated_location].join(" - ")
  end

  def sync_legacy_office_level
    self.office_level = office_category_master&.name.to_s.strip.presence || office_level
  end

  def location_or_parent_present
    return if state_id.present? || district_id.present? || block_id.present? || parent_id.present?

    errors.add(:base, "Select at least one location field or parent office")
  end

  def category_master_matches_stakeholder
    return if stakeholder_category_id.blank? || office_category_master.blank?
    return if office_category_master.stakeholder_category_id == stakeholder_category_id

    errors.add(:office_category_master_id, "must belong to the selected stakeholder")
  end

  def parent_belongs_to_same_stakeholder
    return if parent.blank? || stakeholder_category_id.blank?
    return if parent.stakeholder_category_id == stakeholder_category_id

    errors.add(:parent_id, "must belong to the same stakeholder")
  end

  def parent_cannot_be_self
    return if id.blank? || parent_id.blank?
    return unless id == parent_id

    errors.add(:parent_id, "cannot be the same office")
  end

  def district_belongs_to_state
    return if district.blank? || state.blank? || district.state_id == state_id

    errors.add(:district_id, "must belong to the selected state")
  end

  def block_belongs_to_district
    return if block.blank? || district.blank? || block.district_id == district_id

    errors.add(:block_id, "must belong to the selected district")
  end
end
