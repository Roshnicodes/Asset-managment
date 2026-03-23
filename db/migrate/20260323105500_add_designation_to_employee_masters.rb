class AddDesignationToEmployeeMasters < ActiveRecord::Migration[8.1]
  def change
    add_column :employee_masters, :designation, :string
  end
end
