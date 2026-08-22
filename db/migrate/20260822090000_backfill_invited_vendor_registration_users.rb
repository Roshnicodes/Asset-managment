class BackfillInvitedVendorRegistrationUsers < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE vendor_registrations
      SET user_id = vendor_registration_invitations.user_id,
          updated_at = CURRENT_TIMESTAMP
      FROM vendor_registration_invitations
      WHERE vendor_registrations.id = vendor_registration_invitations.vendor_registration_id
        AND vendor_registrations.user_id IS NULL
        AND vendor_registration_invitations.user_id IS NOT NULL
    SQL
  end

  def down
    # Data backfill only. Do not remove ownership that may now be used for access.
  end
end
