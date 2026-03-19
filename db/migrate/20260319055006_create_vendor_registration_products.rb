class CreateVendorRegistrationProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_registration_products do |t|
      t.references :vendor_registration, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true

      t.timestamps
    end
  end
end
