class RenameLogoToLogoUrlOnStakeholderCategories < ActiveRecord::Migration[8.1]
  def change
    rename_column :stakeholder_categories, :logo, :logo_url
  end
end
