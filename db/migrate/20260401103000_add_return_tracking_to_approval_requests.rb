class AddReturnTrackingToApprovalRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :approval_requests, :return_mode, :string
    add_column :approval_requests, :returned_by_level, :integer
    add_column :approval_requests, :returned_to_level, :integer
  end
end
