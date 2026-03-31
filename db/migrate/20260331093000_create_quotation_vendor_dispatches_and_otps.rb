class CreateQuotationVendorDispatchesAndOtps < ActiveRecord::Migration[8.1]
  def change
    create_table :quotation_vendor_dispatches do |t|
      t.references :quotation_proposal_vendor, null: false, foreign_key: true
      t.references :quotation_proposal, null: false, foreign_key: true
      t.references :vendor_registration, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.references :stakeholder_category, foreign_key: true
      t.string :vendor_name
      t.string :mobile_no
      t.datetime :sent_at
      t.datetime :last_opened_at
      t.datetime :otp_verified_at
      t.datetime :access_expires_at
      t.boolean :access_granted, null: false, default: false
      t.string :status, null: false, default: "sent"

      t.timestamps
    end

    add_index :quotation_vendor_dispatches, :quotation_proposal_vendor_id, unique: true, name: "idx_q_vendor_dispatch_on_proposal_vendor"

    create_table :quotation_vendor_otps do |t|
      t.references :quotation_vendor_dispatch, null: false, foreign_key: true
      t.references :quotation_proposal, null: false, foreign_key: true
      t.references :vendor_registration, null: false, foreign_key: true
      t.string :vendor_name
      t.string :mobile_no
      t.string :otp_code
      t.datetime :sent_at
      t.datetime :expires_at
      t.datetime :verified_at
      t.boolean :verified, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
