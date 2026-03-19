class CreateTos < ActiveRecord::Migration[8.1]
  def change
    create_table :tos do |t|
      t.string :name
      t.references :fco, null: false, foreign_key: true

      t.timestamps
    end
  end
end
