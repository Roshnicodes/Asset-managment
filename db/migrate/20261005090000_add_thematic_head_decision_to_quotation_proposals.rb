class AddThematicHeadDecisionToQuotationProposals < ActiveRecord::Migration[8.1]
  def change
    add_reference :quotation_proposals, :thematic_head, foreign_key: { to_table: :employee_masters }, null: true
    add_column :quotation_proposals, :thematic_head_requested_at, :datetime
    add_column :quotation_proposals, :thematic_head_decision, :string
    add_column :quotation_proposals, :thematic_head_decided_at, :datetime
  end
end
