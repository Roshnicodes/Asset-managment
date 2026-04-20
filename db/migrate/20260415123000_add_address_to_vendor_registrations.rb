class AddAddressToVendorRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :vendor_registrations, :address, :text
  end
end
