class CreateEmployeeMasters < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_masters do |t|
      t.references :stakeholder_category, null: false, foreign_key: true
      t.string :employee_code, null: false
      t.string :name, null: false
      t.string :location
      t.string :email_id

      t.timestamps
    end

    add_index :employee_masters, :employee_code, unique: true
  end
end
