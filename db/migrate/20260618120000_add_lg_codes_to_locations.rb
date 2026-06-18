class AddLgCodesToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :states, :code, :string
    add_column :districts, :code, :string
    add_column :blocks, :code, :string

    add_index :states, :code, unique: true, where: "code IS NOT NULL AND code <> ''"
    add_index :districts, [:state_id, :code], unique: true, where: "code IS NOT NULL AND code <> ''"
    add_index :blocks, [:district_id, :code], unique: true, where: "code IS NOT NULL AND code <> ''"
  end
end
