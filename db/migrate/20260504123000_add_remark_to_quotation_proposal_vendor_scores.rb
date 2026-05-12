class AddRemarkToQuotationProposalVendorScores < ActiveRecord::Migration[8.0]
  def change
    add_column :quotation_proposal_vendor_scores, :remark, :text
  end
end
