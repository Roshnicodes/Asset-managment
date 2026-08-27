class Bank < ApplicationRecord
  DEFAULT_NAMES = [
    "HDFC Bank",
    "ICICI Bank",
    "State Bank of India",
    "Axis Bank",
    "Kotak Mahindra Bank",
    "Punjab National Bank"
  ].freeze

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(Arel.sql("lower(name) ASC")) }

  def self.ensure_default!
    return if exists?

    DEFAULT_NAMES.each { |bank_name| find_or_create_by!(name: bank_name) }
  end
end
