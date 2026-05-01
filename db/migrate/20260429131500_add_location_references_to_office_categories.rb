class AddLocationReferencesToOfficeCategories < ActiveRecord::Migration[8.1]
  def up
    add_reference :office_categories, :state, foreign_key: true unless column_exists?(:office_categories, :state_id)
    add_reference :office_categories, :district, foreign_key: true unless column_exists?(:office_categories, :district_id)
    add_reference :office_categories, :block, foreign_key: true unless column_exists?(:office_categories, :block_id)
  end

  def down
    remove_reference :office_categories, :block, foreign_key: true if column_exists?(:office_categories, :block_id)
    remove_reference :office_categories, :district, foreign_key: true if column_exists?(:office_categories, :district_id)
    remove_reference :office_categories, :state, foreign_key: true if column_exists?(:office_categories, :state_id)
  end
end
