class CreateAssets < ActiveRecord::Migration[8.1]
  def change
    create_table :assets do |t|
      t.string :name
      t.references :product, null: false, foreign_key: true
      t.string :serial_number

      t.timestamps
    end
  end
end
