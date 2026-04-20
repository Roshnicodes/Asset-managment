class AddVendorReferenceNoToQuotationProposalVendors < ActiveRecord::Migration[8.0]
  def change
    add_column :quotation_proposal_vendors, :vendor_reference_no, :string
  end
end
