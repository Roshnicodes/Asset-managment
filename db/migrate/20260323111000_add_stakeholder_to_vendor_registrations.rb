class AddStakeholderToVendorRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_reference :vendor_registrations, :stakeholder_category, foreign_key: true
  end
end
