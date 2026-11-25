class AddAgreementDetailsToQuotationProposalVendors < ActiveRecord::Migration[8.1]
  # Stop dam / earthen dam works: the work site, time and EMD the maker fills on
  # the agreement, kept with the selected vendor (COO approval, vendor link).
  def change
    add_column :quotation_proposal_vendors, :agreement_details, :jsonb, default: {}, null: false
  end
end
