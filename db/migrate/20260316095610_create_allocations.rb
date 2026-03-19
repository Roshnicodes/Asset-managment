class CreateAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :allocations do |t|
      t.references :asset, null: false, foreign_key: true
      t.references :to, null: false, foreign_key: true
      t.date :allocated_at

      t.timestamps
    end
  end
end
