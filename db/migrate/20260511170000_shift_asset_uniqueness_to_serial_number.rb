class ShiftAssetUniquenessToSerialNumber < ActiveRecord::Migration[8.1]
  def change
    remove_index :assets, :asset_code if index_exists?(:assets, :asset_code)
    remove_index :assets, :unique_product_code if index_exists?(:assets, :unique_product_code)

    add_index :assets, :serial_number, unique: true unless index_exists?(:assets, :serial_number)
  end
end
