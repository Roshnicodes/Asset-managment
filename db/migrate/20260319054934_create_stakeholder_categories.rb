class CreateStakeholderCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :stakeholder_categories do |t|
      t.string :name
      t.references :office_category, null: false, foreign_key: true

      t.timestamps
    end
  end
end
