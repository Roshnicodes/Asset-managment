class AddScoreToQuotationProposalVendorCriteriaScores < ActiveRecord::Migration[8.0]
  def up
    add_column :quotation_proposal_vendor_criteria_scores, :score, :integer

    execute <<~SQL.squish
      UPDATE quotation_proposal_vendor_criteria_scores
      SET score = 1
      WHERE score IS NULL
    SQL
  end

  def down
    remove_column :quotation_proposal_vendor_criteria_scores, :score
  end
end
