class CreateBanks < ActiveRecord::Migration[8.1]
  def change
    create_table :banks do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :banks, "lower(name)", unique: true, name: "index_banks_on_lower_name"
  end
end
