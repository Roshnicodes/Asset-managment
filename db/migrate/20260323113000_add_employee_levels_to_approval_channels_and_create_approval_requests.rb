class AddEmployeeLevelsToApprovalChannelsAndCreateApprovalRequests < ActiveRecord::Migration[8.1]
  def change
    add_reference :approval_channels, :level_1_employee, foreign_key: { to_table: :employee_masters }
    add_reference :approval_channels, :level_2_employee, foreign_key: { to_table: :employee_masters }
    add_reference :approval_channels, :level_3_employee, foreign_key: { to_table: :employee_masters }

    create_table :approval_requests do |t|
      t.references :approval_channel, null: false, foreign_key: true
      t.references :approvable, polymorphic: true, null: false
      t.string :status, null: false, default: "pending"
      t.integer :current_level
      t.string :form_name, null: false

      t.timestamps
    end

    create_table :approval_steps do |t|
      t.references :approval_request, null: false, foreign_key: true
      t.references :employee_master, null: false, foreign_key: true
      t.integer :level, null: false
      t.string :status, null: false, default: "waiting"
      t.text :remark
      t.datetime :actioned_at

      t.timestamps
    end
  end
end
