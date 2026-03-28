class MakeRegistrationTypeOptionalOnVendorRegistrations < ActiveRecord::Migration[8.1]
  def change
    change_column_null :vendor_registrations, :registration_type_id, true
  end
end
