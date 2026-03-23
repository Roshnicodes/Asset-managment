class CreateApprovalChannelStepsAndExpandApprovalSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_channel_steps do |t|
      t.references :approval_channel, null: false, foreign_key: true
      t.integer :step_number, null: false
      t.references :from_user, foreign_key: { to_table: :employee_masters }
      t.references :to_responsible_user, null: false, foreign_key: { to_table: :employee_masters }
      t.string :previous_action
      t.string :current_action, null: false

      t.timestamps
    end

    add_index :approval_channel_steps, [:approval_channel_id, :step_number], unique: true

    add_reference :approval_steps, :from_user, foreign_key: { to_table: :employee_masters }
    add_column :approval_steps, :previous_action, :string
    add_column :approval_steps, :current_action, :string
  end
end
