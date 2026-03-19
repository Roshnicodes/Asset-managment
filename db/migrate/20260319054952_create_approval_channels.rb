class CreateApprovalChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_channels do |t|
      t.string :form_name
      t.string :approval_type
      t.string :level_1_approver
      t.string :level_2_approver
      t.string :level_3_approver

      t.timestamps
    end
  end
end
