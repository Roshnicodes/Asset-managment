class AddQrFieldsToQuotationProposalVendors < ActiveRecord::Migration[8.1]
  def change
    add_column :quotation_proposal_vendors, :qr_token, :string
    add_column :quotation_proposal_vendors, :qr_generated_at, :datetime

    add_index :quotation_proposal_vendors, :qr_token, unique: true
  end
end
