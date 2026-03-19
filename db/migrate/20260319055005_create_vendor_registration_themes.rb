class CreateVendorRegistrationThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_registration_themes do |t|
      t.references :vendor_registration, null: false, foreign_key: true
      t.references :theme, null: false, foreign_key: true

      t.timestamps
    end
  end
end
