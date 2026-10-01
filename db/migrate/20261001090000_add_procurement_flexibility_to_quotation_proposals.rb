class AddProcurementFlexibilityToQuotationProposals < ActiveRecord::Migration[8.1]
  def change
    add_column :quotation_proposals, :committee_approval_required, :boolean, null: false, default: true
    add_column :quotation_proposals, :quotation_valid_until, :date
    add_reference :quotation_proposals,
                  :reused_from_quotation_proposal,
                  foreign_key: { to_table: :quotation_proposals }

    add_index :vendor_registrations, :mobile_no
  end
end
