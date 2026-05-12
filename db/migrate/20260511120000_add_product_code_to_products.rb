class AddProductCodeToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :product_code, :string
    add_index :products, :product_code, unique: true
  end
end
