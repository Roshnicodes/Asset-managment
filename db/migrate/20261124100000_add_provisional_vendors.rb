# A vendor added to a quotation of up to 50K without a registration is kept as
# a provisional vendor registration (name, firm, mobile only). It becomes a
# full registration when the vendor completes the registration link.
class AddProvisionalVendors < ActiveRecord::Migration[8.1]
  def change
    add_column :vendor_registrations, :provisional, :boolean, default: false, null: false
    add_index :vendor_registrations, :provisional

    change_column_null :vendor_registrations, :state_id, true
    change_column_null :vendor_registrations, :district_id, true
    change_column_null :vendor_registrations, :block_id, true
    change_column_null :vendor_registrations, :submitted_at, true
    change_column_null :vendor_registrations, :submitted_ip, true
  end
end
