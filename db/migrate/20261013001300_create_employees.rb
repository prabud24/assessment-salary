class CreateEmployees < ActiveRecord::Migration[7.2]
  def change
    create_table :employees do |t|
      t.string :employee_number, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :country_code, limit: 2, null: false
      t.string :department, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :employees, :employee_number, unique: true
    add_index :employees, "lower(email)", unique: true, name: "index_employees_on_lower_email"
    add_index :employees, :country_code
    add_index :employees, :department

    add_check_constraint :employees,
      "employee_number ~ '^EMP[0-9]{5}$' AND employee_number <> 'EMP00000'",
      name: "employees_employee_number_format"
    add_check_constraint :employees,
      "status IN ('active', 'inactive')",
      name: "employees_status_allowed"
    add_check_constraint :employees,
      "country_code ~ '^[A-Z]{2}$'",
      name: "employees_country_code_format"
  end
end
