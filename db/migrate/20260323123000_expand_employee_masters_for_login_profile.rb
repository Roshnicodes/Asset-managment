class ExpandEmployeeMastersForLoginProfile < ActiveRecord::Migration[8.1]
  def change
    change_column_null :employee_masters, :employee_code, true

    add_column :employee_masters, :user_type, :string
    add_column :employee_masters, :mobile_no, :string
    add_reference :employee_masters, :state, foreign_key: true
    add_reference :employee_masters, :district, foreign_key: true
    add_reference :employee_masters, :block, foreign_key: true
    add_column :employee_masters, :gram_panchayat, :string
    add_column :employee_masters, :village, :string
    add_column :employee_masters, :parent_office, :string
    add_column :employee_masters, :office, :string
    add_column :employee_masters, :full_address, :text
    add_column :employee_masters, :pincode, :string
  end
end
