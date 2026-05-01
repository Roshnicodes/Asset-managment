class CreateOfficeCategoryMastersAndLinkOfficeCategories < ActiveRecord::Migration[8.1]
  class OfficeCategory < ApplicationRecord
    self.table_name = "office_categories"
  end

  class OfficeCategoryMaster < ApplicationRecord
    self.table_name = "office_category_masters"
  end

  def up
    create_table :office_category_masters do |t|
      t.references :stakeholder_category, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :office_category_masters,
              [:stakeholder_category_id, :name],
              unique: true,
              name: "index_office_category_masters_on_stakeholder_and_name"

    add_reference :office_categories, :office_category_master, foreign_key: true

    OfficeCategory.reset_column_information
    OfficeCategoryMaster.reset_column_information

    OfficeCategory.find_each do |office_category|
      next if office_category.stakeholder_category_id.blank? || office_category.office_level.blank?

      master = OfficeCategoryMaster.find_or_create_by!(
        stakeholder_category_id: office_category.stakeholder_category_id,
        name: office_category.office_level.to_s.strip
      )

      office_category.update_columns(office_category_master_id: master.id)
    end
  end

  def down
    remove_reference :office_categories, :office_category_master, foreign_key: true
    remove_index :office_category_masters, name: "index_office_category_masters_on_stakeholder_and_name"
    drop_table :office_category_masters
  end
end
