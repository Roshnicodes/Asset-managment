class CreatePmus < ActiveRecord::Migration[8.1]
  def change
    create_table :pmus do |t|
      t.string :name
      t.references :district, null: false, foreign_key: true

      t.timestamps
    end
  end
end
