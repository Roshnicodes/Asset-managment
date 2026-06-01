class CreateVendorRegistrationInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_registration_invitations do |t|
      t.references :user, foreign_key: true
      t.references :stakeholder_category, foreign_key: true
      t.references :vendor_registration, foreign_key: true
      t.string :mobile_no, null: false
      t.string :token, null: false
      t.string :otp_code
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :otp_sent_at
      t.datetime :otp_expires_at
      t.datetime :otp_verified_at
      t.datetime :access_expires_at
      t.string :status, null: false, default: "draft"

      t.timestamps
    end

    add_index :vendor_registration_invitations, :token, unique: true
    add_index :vendor_registration_invitations, :mobile_no
  end
end
