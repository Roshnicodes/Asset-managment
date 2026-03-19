class CreateProductVarieties < ActiveRecord::Migration[8.1]
  def change
    create_table :product_varieties do |t|
      t.string :name
      t.references :product, null: false, foreign_key: true

      t.timestamps
    end
  end
end
