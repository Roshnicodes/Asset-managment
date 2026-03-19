class CreateVendorRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_registrations do |t|
      t.references :registration_type, null: false, foreign_key: true
      t.string :company_name
      t.references :firm, foreign_key: true
      t.string :vendor_name
      t.string :firm_type
      t.string :gst_no
      t.string :pan_no
      t.string :email
      t.string :mobile_no
      t.references :state, null: false, foreign_key: true
      t.references :district, null: false, foreign_key: true
      t.references :block, null: false, foreign_key: true
      t.string :pin_no
      t.string :contact_person_name
      t.string :contact_person_designation
      t.boolean :msme
      t.string :msme_number
      t.string :company_status
      t.text :business_description
      t.datetime :submitted_at, null: false
      t.string :submitted_ip, null: false

      t.timestamps
    end
  end
end
