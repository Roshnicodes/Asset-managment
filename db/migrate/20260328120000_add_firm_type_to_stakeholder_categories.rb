class AddFirmTypeToStakeholderCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :stakeholder_categories, :firm_type, :string
  end
end
