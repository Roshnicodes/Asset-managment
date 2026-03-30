class AddFirmProfileToVendorRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :vendor_registrations, :firm_profile, :text
  end
end
