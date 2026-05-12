class CreateVendorSelectionCriteria < ActiveRecord::Migration[8.0]
  def change
    create_table :vendor_selection_criteria do |t|
      t.references :theme, null: false, foreign_key: true
      t.text :criteria, null: false

      t.timestamps
    end
  end
end
