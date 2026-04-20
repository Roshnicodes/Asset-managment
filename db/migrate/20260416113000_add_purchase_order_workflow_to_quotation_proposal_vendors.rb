class AddPurchaseOrderWorkflowToQuotationProposalVendors < ActiveRecord::Migration[7.1]
  def change
    change_table :quotation_proposal_vendors, bulk: true do |t|
      t.string :po_token
      t.string :purchase_order_status, null: false, default: "draft"
      t.datetime :purchase_order_sent_at
      t.datetime :purchase_order_actioned_at
      t.text :purchase_order_remark
      t.references :purchase_order_authorized_by, foreign_key: { to_table: :employee_masters }
    end

    add_index :quotation_proposal_vendors, :po_token, unique: true
  end
end
