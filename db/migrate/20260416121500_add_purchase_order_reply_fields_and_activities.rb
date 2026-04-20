class AddPurchaseOrderReplyFieldsAndActivities < ActiveRecord::Migration[7.1]
  def change
    change_table :quotation_proposal_vendors, bulk: true do |t|
      t.text :purchase_order_reply
      t.datetime :purchase_order_reply_updated_at
      t.references :purchase_order_reply_updated_by, foreign_key: { to_table: :employee_masters }
    end

    create_table :quotation_proposal_vendor_po_activities do |t|
      t.references :quotation_proposal_vendor, null: false, foreign_key: true, index: { name: "idx_po_activities_on_vendor" }
      t.references :employee_master, foreign_key: true
      t.references :user, foreign_key: true
      t.string :action_type, null: false
      t.string :actor_name, null: false
      t.string :actor_role
      t.text :note
      t.datetime :occurred_at, null: false
      t.timestamps
    end
  end
end
