class ExpandStakeholderCategoriesAndLinkToMasters < ActiveRecord::Migration[8.1]
  def change
    change_table :stakeholder_categories, bulk: true do |t|
      t.text :address
      t.string :logo
      t.string :contact_no
      t.string :email_id
    end

    add_reference :office_categories, :stakeholder_category, foreign_key: true
    add_reference :registration_types, :stakeholder_category, foreign_key: true
    add_reference :service_types, :stakeholder_category, foreign_key: true
    add_reference :themes, :stakeholder_category, foreign_key: true
    add_reference :products, :stakeholder_category, foreign_key: true
    add_reference :product_varieties, :stakeholder_category, foreign_key: true
    add_reference :units, :stakeholder_category, foreign_key: true
    add_reference :document_masters, :stakeholder_category, foreign_key: true
    add_reference :approval_channels, :stakeholder_category, foreign_key: true
    add_reference :firms, :stakeholder_category, foreign_key: true
    add_reference :vendor_bank_masters, :stakeholder_category, foreign_key: true
  end
end
