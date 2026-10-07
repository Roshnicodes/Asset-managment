# Indexes for lookups that run on most pages: the logged-in employee by email,
# the unread notification count, approval trails and pending approvals.
class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :employee_masters, "lower(trim(email_id))", name: "index_employee_masters_on_lower_trim_email_id", algorithm: :concurrently, if_not_exists: true
    add_index :notifications, [:user_id, :status], algorithm: :concurrently, if_not_exists: true
    add_index :approval_steps, [:approval_request_id, :level], algorithm: :concurrently, if_not_exists: true
    add_index :approval_steps, [:employee_master_id, :status], algorithm: :concurrently, if_not_exists: true
    add_index :approval_requests, :status, algorithm: :concurrently, if_not_exists: true
    add_index :quotation_proposal_committee_steps, [:employee_master_id, :status], name: "index_qp_committee_steps_on_employee_and_status", algorithm: :concurrently, if_not_exists: true
    add_index :vendor_registration_invitations, :status, algorithm: :concurrently, if_not_exists: true
    add_index :quotation_proposals, :created_at, algorithm: :concurrently, if_not_exists: true
    add_index :vendor_registrations, :created_at, algorithm: :concurrently, if_not_exists: true
  end
end
