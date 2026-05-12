class CreateQuotationProposalCriteriaSelections < ActiveRecord::Migration[8.0]
  def change
    create_table :quotation_proposal_criteria_selections do |t|
      t.references :quotation_proposal, null: false, foreign_key: true
      t.references :vendor_selection_criterion,
                   null: true,
                   foreign_key: { to_table: :vendor_selection_criteria, on_delete: :nullify }
      t.text :criterion_label, null: false

      t.timestamps
    end

    add_index :quotation_proposal_criteria_selections,
              [:quotation_proposal_id, :vendor_selection_criterion_id],
              unique: true,
              name: "idx_qp_criteria_selections_unique"
  end
end
