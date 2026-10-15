class AddMailFieldsToPaymentAdvices < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_advices, :cc_emails, :string
    add_column :payment_advices, :bcc_emails, :string
    add_column :payment_advices, :mail_sent_at, :datetime
  end
end
