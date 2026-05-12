class CreateQuotationProposalVendorCriteriaScores < ActiveRecord::Migration[8.0]
  def change
    create_table :quotation_proposal_vendor_criteria_scores do |t|
      t.references :quotation_proposal_vendor, null: false, foreign_key: true
      t.references :quotation_proposal_criteria_selection, null: false, foreign_key: true
      t.references :employee_master, null: false, foreign_key: true

      t.timestamps
    end

    add_index :quotation_proposal_vendor_criteria_scores,
              [:quotation_proposal_vendor_id, :quotation_proposal_criteria_selection_id, :employee_master_id],
              unique: true,
              name: "idx_qp_vendor_criteria_scores_unique"
  end
end
