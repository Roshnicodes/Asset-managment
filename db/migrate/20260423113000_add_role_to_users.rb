class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :role, :integer, null: false, default: 0

    execute <<~SQL
      UPDATE users
      SET role = 1
      FROM employee_masters
      WHERE LOWER(TRIM(employee_masters.email_id)) = LOWER(TRIM(users.email))
        AND employee_masters.user_type = 'Admin'
    SQL

    execute <<~SQL
      UPDATE users
      SET role = 1
      WHERE LOWER(TRIM(email)) = 'admin@example.com'
    SQL
  end

  def down
    remove_column :users, :role
  end
end
