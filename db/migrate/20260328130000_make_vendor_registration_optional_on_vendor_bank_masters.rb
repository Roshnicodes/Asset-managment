class MakeVendorRegistrationOptionalOnVendorBankMasters < ActiveRecord::Migration[8.1]
  def change
    change_column_null :vendor_bank_masters, :vendor_registration_id, true
  end
end
