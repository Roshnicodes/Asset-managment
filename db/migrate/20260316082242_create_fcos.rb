class CreateFcos < ActiveRecord::Migration[8.1]
  def change
    create_table :fcos do |t|
      t.string :name
      t.references :pmu, null: false, foreign_key: true

      t.timestamps
    end
  end
end
