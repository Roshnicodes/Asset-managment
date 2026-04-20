class Asset < ApplicationRecord
  belongs_to :product
  belongs_to :quotation_proposal_vendor_invoice_request, optional: true
  belongs_to :quotation_proposal_vendor_item, optional: true
  has_many :allocations, dependent: :destroy

  before_validation :assign_asset_code, on: :create

  validates :asset_code, uniqueness: true, allow_blank: true
  validates :unique_product_code, uniqueness: true, allow_blank: true

  scope :recent_first, -> { order(created_at: :desc) }

  private

  def assign_asset_code
    return if asset_code.present?

    self.asset_code = self.class.generate_asset_code
  end

  def self.generate_asset_code
    loop do
      code = "AST/#{Date.current.year}/#{SecureRandom.random_number(100_000..999_999)}"
      break code unless exists?(asset_code: code)
    end
  end
end
