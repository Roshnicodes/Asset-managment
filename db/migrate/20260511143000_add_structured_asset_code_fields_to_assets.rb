class AddStructuredAssetCodeFieldsToAssets < ActiveRecord::Migration[8.1]
  def change
    add_reference :assets, :stakeholder_category, foreign_key: true
    add_reference :assets, :primary_office_category, foreign_key: { to_table: :office_categories }
    add_reference :assets, :secondary_office_category, foreign_key: { to_table: :office_categories }
    add_column :assets, :asset_code_date, :date
  end
end
