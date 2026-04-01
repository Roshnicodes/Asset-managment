class CreateVendorRegistrationDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_registration_documents do |t|
      t.references :vendor_registration, null: false, foreign_key: true
      t.references :document_master, null: false, foreign_key: true

      t.timestamps
    end

    add_index :vendor_registration_documents,
              [:vendor_registration_id, :document_master_id],
              unique: true,
              name: "idx_vendor_registration_documents_unique"
  end
end
