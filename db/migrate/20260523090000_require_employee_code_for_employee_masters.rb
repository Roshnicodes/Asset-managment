class RequireEmployeeCodeForEmployeeMasters < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      WITH employees_without_codes AS (
        SELECT id
        FROM employee_masters
        WHERE employee_code IS NULL OR TRIM(employee_code) = ''
      )
      UPDATE employee_masters
      SET employee_code = 'EMP-AUTO-' || employees_without_codes.id::text
      FROM employees_without_codes
      WHERE employee_masters.id = employees_without_codes.id
    SQL

    change_column_null :employee_masters, :employee_code, false
  end

  def down
    change_column_null :employee_masters, :employee_code, true
  end
end
