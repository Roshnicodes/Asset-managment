class CreateVendorBankMasters < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_bank_masters do |t|
      t.references :vendor_registration, null: false, foreign_key: true
      t.string :bank_name
      t.text :bank_address
      t.string :ifsc_code
      t.string :account_number
      t.string :account_type

      t.timestamps
    end
  end
end
