# WRD requests choose an Activity (a WRD product such as Stop Dam); the items
# under it are typed by the maker.
class AddActivityProductToQuotationProposals < ActiveRecord::Migration[8.1]
  def change
    add_reference :quotation_proposals, :activity_product, foreign_key: { to_table: :products }, null: true
  end
end
