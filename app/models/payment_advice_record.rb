class PaymentAdviceRecord < ApplicationRecord
  self.table_name = "payment_advices"

  EMAIL_FIELDS = %i[payee_email cc_emails bcc_emails].freeze
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP

  validates :company_name, :advice_no, :payee_name, :invoice_no, :payment_mode, presence: true
  validates :advice_no, uniqueness: true
  validate :email_lists_are_valid
  validate :locked_after_mail_sent, on: :update

  before_validation :normalize_email_lists
  before_validation :calculate_net_amount

  scope :recent, -> { order(created_at: :desc) }

  # Numbers run per year: PA-2026-001, PA-2026-002 ... then PA-2027-001.
  def self.next_advice_no(year: Date.current.year)
    pattern = /\APA-#{year}-(\d{3,})\z/
    last_number = where("advice_no LIKE ?", "PA-#{year}-%").pluck(:advice_no).filter_map do |advice_no|
      advice_no.to_s.match(pattern)&.[](1)&.to_i
    end.max.to_i

    format("PA-#{year}-%03d", last_number + 1)
  end

  # Every address used before, for the email suggestions (newest first).
  def self.used_emails(limit: 300)
    recent.limit(500).pluck(:payee_email, :cc_emails, :bcc_emails).flatten
      .flat_map { |value| split_emails(value) }.uniq(&:downcase).first(limit)
  end

  def self.split_emails(value)
    value.to_s.split(/[,;\s]+/).map(&:strip).reject(&:blank?)
  end

  def mail_sent?
    mail_sent_at.present?
  end

  def to_list = self.class.split_emails(payee_email)
  def cc_list = self.class.split_emails(cc_emails)
  def bcc_list = self.class.split_emails(bcc_emails)

  private

  def normalize_email_lists
    EMAIL_FIELDS.each do |field|
      next unless will_save_change_to_attribute?(field) || new_record?

      list = self.class.split_emails(self[field]).uniq(&:downcase)
      self[field] = list.join(", ").presence
    end
  end

  def email_lists_are_valid
    { payee_email: "Recipient Email", cc_emails: "CC", bcc_emails: "BCC" }.each do |field, label|
      wrong = self.class.split_emails(self[field]).reject { |email| email.match?(EMAIL_FORMAT) }
      errors.add(:base, "#{label} has an invalid email: #{wrong.join(', ')}") if wrong.any?
    end
  end

  # Once the advice has been mailed it is final; only the sent time may change.
  def locked_after_mail_sent
    return if mail_sent_at_in_database.blank?

    return if (changes_to_save.keys - %w[mail_sent_at updated_at]).empty?

    errors.add(:base, "This payment advice was already mailed on #{mail_sent_at_in_database.in_time_zone('Asia/Kolkata').strftime('%d %b %Y %I:%M %p')} and can no longer be edited.")
  end

  def calculate_net_amount
    self.net_amount = gross_amount.to_d - tds_amount.to_d - other_deduction.to_d
    self.net_amount = 0 if net_amount.negative?
  end
end
