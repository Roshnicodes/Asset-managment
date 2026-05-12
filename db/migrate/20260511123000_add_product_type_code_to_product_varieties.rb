class AddProductTypeCodeToProductVarieties < ActiveRecord::Migration[8.1]
  def change
    add_column :product_varieties, :product_type_code, :string
    add_index :product_varieties, :product_type_code, unique: true
  end
end
