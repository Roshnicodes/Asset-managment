class AddDependentDestroyToApprovalRequestsChannel < ActiveRecord::Migration[8.0]
  def change
    # Drop existing FK without cascade, then re-add with ON DELETE CASCADE
    remove_foreign_key :approval_requests, :approval_channels
    add_foreign_key :approval_requests, :approval_channels, on_delete: :cascade
  end
end
