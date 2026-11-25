class AddOrderDocumentTypeToQuotationProposals < ActiveRecord::Migration[8.1]
  # WRD: the maker chooses with the Activity whether the selected vendor gets a
  # Purchase Order, a Work Order (same flow, named Work Order) or an Agreement.
  def change
    add_column :quotation_proposals, :order_document_type, :string
  end
end
