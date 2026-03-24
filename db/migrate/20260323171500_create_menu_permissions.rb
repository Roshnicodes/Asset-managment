class CreateMenuPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :menu_permissions do |t|
      t.references :stakeholder_category, null: false, foreign_key: true
      t.string :designation, null: false
      t.string :menu_identifier, null: false
      t.boolean :can_view, default: false

      t.timestamps
    end
    add_index :menu_permissions, [:stakeholder_category_id, :designation, :menu_identifier], unique: true, name: 'idx_menu_permissions_composite'
  end
end
