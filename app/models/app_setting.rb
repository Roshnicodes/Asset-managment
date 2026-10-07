# Small key/value store for options an admin can change from the app.
class AppSetting < ApplicationRecord
  SINGLE_VENDOR_APPROVER = "single_vendor_approver_designation".freeze
  SINGLE_VENDOR_APPROVER_OPTIONS = %w[Director COO].freeze
  SINGLE_VENDOR_APPROVER_DEFAULT = "Director".freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key, default = nil)
    find_by(key: key)&.value.presence || default
  end

  def self.set(key, value)
    setting = find_or_initialize_by(key: key)
    setting.update!(value: value)
    setting
  end

  # Who approves an Above 10K request with a single vendor: Director by
  # default, COO when the admin chooses it.
  def self.single_vendor_approver_designation
    value = get(SINGLE_VENDOR_APPROVER, SINGLE_VENDOR_APPROVER_DEFAULT)
    SINGLE_VENDOR_APPROVER_OPTIONS.include?(value) ? value : SINGLE_VENDOR_APPROVER_DEFAULT
  end
end
