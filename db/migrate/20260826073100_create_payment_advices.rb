class CreatePaymentAdvices < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_advices do |t|
      t.string :company_name, null: false
      t.string :advice_no, null: false
      t.string :payee_name, null: false
      t.string :payee_email
      t.string :invoice_no, null: false
      t.date :invoice_date
      t.decimal :gross_amount, precision: 14, scale: 2, default: 0, null: false
      t.decimal :tds_amount, precision: 14, scale: 2, default: 0, null: false
      t.decimal :other_deduction, precision: 14, scale: 2, default: 0, null: false
      t.decimal :net_amount, precision: 14, scale: 2, default: 0, null: false
      t.string :payment_mode, null: false
      t.string :reference_no
      t.string :bank_name
      t.date :payment_date
      t.text :remarks

      t.timestamps
    end

    add_index :payment_advices, :advice_no, unique: true
  end
end
