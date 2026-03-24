class AddUserIdToVendorRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_reference :vendor_registrations, :user, null: true, foreign_key: true
  end
end
