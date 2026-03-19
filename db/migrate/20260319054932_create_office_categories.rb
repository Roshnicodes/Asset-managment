class CreateOfficeCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :office_categories do |t|
      t.string :name
      t.string :office_level
      t.bigint :parent_id

      t.timestamps
    end

    add_index :office_categories, :parent_id
  end
end
