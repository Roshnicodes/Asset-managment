class AddVendorCoverNoteToQuotationProposalVendors < ActiveRecord::Migration[8.1]
  def change
    add_column :quotation_proposal_vendors, :vendor_cover_note, :text
  end
end
