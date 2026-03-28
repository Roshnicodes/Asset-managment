class RenameCompanyNameToFirmNameOnVendorRegistrations < ActiveRecord::Migration[8.1]
  def change
    rename_column :vendor_registrations, :company_name, :firm_name
  end
end
