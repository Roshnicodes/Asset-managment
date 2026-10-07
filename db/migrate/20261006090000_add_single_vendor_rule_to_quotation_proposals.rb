class AddSingleVendorRuleToQuotationProposals < ActiveRecord::Migration[8.1]
  def change
    # Quotations created from now on follow the vendor-count rule (3+ vendors,
    # or exactly 1 with a justification note). Existing quotations keep false
    # and are not affected.
    add_column :quotation_proposals, :vendor_rule_enforced, :boolean, default: false, null: false
    add_column :quotation_proposals, :single_vendor_justification, :text
  end
end
