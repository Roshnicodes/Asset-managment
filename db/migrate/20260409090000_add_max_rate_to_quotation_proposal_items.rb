class AddMaxRateToQuotationProposalItems < ActiveRecord::Migration[8.0]
  def change
    add_column :quotation_proposal_items, :max_rate, :decimal, precision: 12, scale: 2
  end
end
