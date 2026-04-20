class CreateQuotationProposalVendorScores < ActiveRecord::Migration[8.1]
  def change
    create_table :quotation_proposal_vendor_scores do |t|
      t.references :quotation_proposal_vendor, null: false, foreign_key: true
      t.references :employee_master, null: false, foreign_key: true
      t.integer :score

      t.timestamps
    end

    add_index :quotation_proposal_vendor_scores,
              [:quotation_proposal_vendor_id, :employee_master_id],
              unique: true,
              name: "idx_qp_vendor_scores_on_vendor_and_employee"
  end
end
