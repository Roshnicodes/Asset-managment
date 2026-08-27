class PaymentAdviceRecord < ApplicationRecord
  self.table_name = "payment_advices"

  validates :company_name, :advice_no, :payee_name, :invoice_no, :payment_mode, presence: true
  validates :advice_no, uniqueness: true

  before_validation :calculate_net_amount

  scope :recent, -> { order(created_at: :desc) }

  def self.next_advice_no
    last_number = pluck(:advice_no).filter_map do |advice_no|
      advice_no.to_s.match(/\APA-2026-(\d{3})\z/)&.[](1)&.to_i
    end.max.to_i

    format("PA-2026-%03d", last_number + 1)
  end

  private

  def calculate_net_amount
    self.net_amount = gross_amount.to_d - tds_amount.to_d - other_deduction.to_d
    self.net_amount = 0 if net_amount.negative?
  end
end
